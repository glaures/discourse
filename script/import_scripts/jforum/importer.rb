require_relative '../base'
require_relative 'support/settings'
require_relative 'database/database'
require_relative 'importers/importer_factory'

module ImportScripts::JForum
  class Importer < ImportScripts::Base
    # @param settings [ImportScripts::JForum::Settings]
    # @param database [ImportScripts::JForum::Database_2_1]
    def initialize(settings, database)
      @settings = settings
      super()

      @database = database
      @importers = ImporterFactory.new(@database, @lookup, @uploader, @settings)
    end

    def perform
      super if settings_check_successful?
    end

    protected

    def execute
      puts '', "importing from jforum"

      import_users
      import_categories
      import_emojis
      import_posts
      import_private_messages if @settings.import_private_messages
      import_bookmarks if @settings.import_bookmarks
      mark_all_topics_as_read if @settings.mark_all_topics_as_read
    end

    def change_site_settings
      super

      @importers.permalink_importer.change_site_settings
    end

    def get_site_settings_for_import
      settings = super

      max_file_size_kb = @database.get_max_attachment_size
      settings[:max_image_size_kb] = [max_file_size_kb, SiteSetting.max_image_size_kb].max
      settings[:max_attachment_size_kb] = [max_file_size_kb, SiteSetting.max_attachment_size_kb].max

      # temporarily disable validation since we want to import all existing images and attachments
      SiteSetting.type_supervisor.load_setting(:max_image_size_kb, max: settings[:max_image_size_kb])
      SiteSetting.type_supervisor.load_setting(:max_attachment_size_kb, max: settings[:max_attachment_size_kb])

      settings
    end

    def settings_check_successful?
      true
    end

    def import_users
      puts '', 'creating users'
      total_count = @database.count_users
      importer = @importers.user_importer
      last_user_id = 0

      batches do |offset|
        rows, last_user_id = @database.fetch_users(last_user_id)
        break if rows.size < 1

        next if all_records_exist?(:users, importer.map_users_to_import_ids(rows))

        create_users(rows, total: total_count, offset: offset) do |row|
          importer.map_user(row)
        end
      end
    end

    def import_categories
      puts '', 'creating categories'
      rows = @database.fetch_categories
      importer = @importers.category_importer

      create_categories(rows) do |row|
        importer.map_category(row)
      end
    end

    def import_posts
      puts '', 'creating topics and posts'
      total_count = @database.count_posts
      importer = @importers.post_importer
      last_post_id = 0

      batches do |offset|
        rows, last_post_id = @database.fetch_posts(last_post_id)
        break if rows.size < 1

        next if all_records_exist?(:posts, importer.map_to_import_ids(rows))

        create_posts(rows, total: total_count, offset: offset) do |row|
          importer.map_post(row)
        end
      end
    end

    def import_private_messages
      puts '', 'creating private messages'
      total_count = @database.count_messages
      importer = @importers.message_importer
      last_msg_id = 0

      batches do |offset|
        rows, last_msg_id = @database.fetch_messages(last_msg_id)
        break if rows.size < 1

        next if all_records_exist?(:posts, importer.map_to_import_ids(rows))

        create_posts(rows, total: total_count, offset: offset) do |row|
          importer.map_message(row)
        end
      end
    end

    def import_bookmarks
      puts '', 'creating bookmarks'
      total_count = @database.count_bookmarks
      importer = @importers.bookmark_importer
      last_user_id = last_bookmark_id = 0

      batches do |offset|
        rows, last_bookmark_id = @database.fetch_bookmarks(last_user_id, last_bookmark_id)
        break if rows.size < 1

        create_bookmarks(rows, total: total_count, offset: offset) do |row|
          importer.map_bookmark(row)
        end
      end
    end

    def import_emojis
      puts '', 'creating custom emojis'
      total_count = @database.count_smilies
      last_smilie_id = 0

      batches do |offset|
        rows, last_smilie_id = @database.fetch_smilies(last_smilie_id)
        break if rows.size < 1

        create_emojis(rows, total: total_count, offset: offset)
      end
    end

    def create_emojis(rows, opts = {})
      created = 0
      skipped = 0
      total = opts[:total] || rows.size
      importer = @importers.emoji_importer

      rows.each do |row|
        if row.nil?
          skipped += 1
        else
          emoji = importer.import_emoji(row[:code], row[:disk_name])
          if emoji.nil?
            skipped += 1
          else
            created += 1
          end
        end

        print_status created + skipped + (opts[:offset] || 0), total
      end

      [created, skipped]
    end

    def mark_all_topics_as_read
      puts '', "marking all topics as read"

      Topic.exec_sql <<~SQL
        UPDATE topic_users tu
        SET highest_seen_post_number = t.highest_post_number, last_read_post_number = highest_post_number
        FROM topics t
        WHERE t.id = tu.topic_id
      SQL
    end

    def update_last_seen_at
      # no need for this since the importer sets last_seen_at for each user during the import
    end

    # Do not use the bbcode_to_md in base.rb. It will be used in text_processor.rb instead.
    def use_bbcode_to_md?
      false
    end

    def batches
      super(@settings.database.batch_size)
    end
  end
end
