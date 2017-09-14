module ImportScripts::JForum
  class PermalinkImporter
    CATEGORY_LINK_NORMALIZATION = '/(forums/show)(/\d+)?(/\d+\.page).*/\1\3'
    #POST_LINK_NORMALIZATION = '/(posts/list)(/\d+)?(/\d+\.page).*/\1\3'
    TOPIC_LINK_NORMALIZATION = '/(posts/list)(/\d+)?(/\d+\.page).*/\1\3'

    # @param settings [ImportScripts::JForum::PermalinkSettings]
    def initialize(settings)
      @settings = settings
    end

    def change_site_settings
      normalizations = SiteSetting.permalink_normalizations
      normalizations = normalizations.blank? ? [] : normalizations.split('|')

      add_normalization(normalizations, CATEGORY_LINK_NORMALIZATION) if @settings.create_category_links
      #add_normalization(normalizations, POST_LINK_NORMALIZATION) if @settings.create_post_links
      add_normalization(normalizations, TOPIC_LINK_NORMALIZATION) if @settings.create_topic_links

      SiteSetting.permalink_normalizations = normalizations.join('|')
    end

    def create_for_category(category, import_id)
      return unless @settings.create_category_links && category

      url = "/forums/show/#{import_id}.page"

      Permalink.create(url: url, category_id: category.id) unless permalink_exists(url)
    end

    def create_for_topic(topic, import_id)
      return unless @settings.create_topic_links && topic

      url = "/posts/list/#{import_id}.page"

      Permalink.create(url: url, topic_id: topic.id) unless permalink_exists(url)
    end

    def create_for_post(post, import_id)
      return unless @settings.create_topic_links && post

      url = "/posts/list/#{post.topic.id}.page\##{import_id}"

      Permalink.create(url: url, post_id: post.id) unless permalink_exists(url)
    end

    protected

    def add_normalization(normalizations, normalization)
      normalizations << normalization unless normalizations.include?(normalization)
    end

    def permalink_exists(url)
      Permalink.find_by(url: url)
    end
  end
end
