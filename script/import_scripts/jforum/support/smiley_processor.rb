module ImportScripts::JForum
  class SmileyProcessor
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(uploader, settings)
      @uploader = uploader

      @smilies_path = File.join(settings.base_dir, Constants::SUBDIR_SMILIES)

      @smiley_map = {}
      add_default_smilies
      add_configured_smilies(settings.emojis)
    end

    def replace_smilies(text)
      @smiley_map.each do |smiley, emoji|
        text.gsub!(/(^|[[:punct:]]|\s)#{Regexp.quote(smiley)}($|[[:punct:]]|\s)/, "\\1#{emoji}\\2")
      end
    end

    def has_smiley?(smiley)
      @smiley_map.has_key?(smiley)
    end

    protected

    def add_default_smilies
      {
        # these emojis are default smilies from JForum
        [':shock:'] => ':open_mouth:',
        [':lol:'] => ':laughing:',
        [':oops:'] => ':blush:',
        [':cry:'] => ':cry:',
        [':evil:'] => ':imp:',
        [':twisted:'] => ':smiling_imp:',
        [':roll:'] => ':unamused:',
        [':idea:'] => ':bulb:',
        [':arrow:'] => ':arrow_right:',
        [':!:'] => ':exclamation:',
        [':o', ':-o', ':eek:'] => ':astonished:',
        [':?', ':-?', ':???:'] => ':confused:',
        ['8-)', '8)', ':cool:'] => ':sunglasses:',
        [':x', ':-x', ':mad:'] => ':angry:',
        [':?:', ':?'] => ':question:',

        # these emojis are also supported as translations by discourse
        [':D', ':-D', ':grin:'] => ':smiley:',
        [':)', ':-)', ':smile:'] => ':slight_smile:',
        [';)', ';-)', ':wink:'] => ':wink:',
        [':(', ':-(', ':sad:'] => ':frowning:',
        [':P', ':-P', ':razz:'] => ':stuck_out_tongue:',
        [':|', ':-|'] => ':neutral_face:'
      }.each do |smilies, emoji|
        smilies.each { |smiley| @smiley_map[smiley] = emoji }
      end
    end

    def add_configured_smilies(emojis)
      return if emojis.nil?
      emojis.each do |emoji, smilies|
        Array.wrap(smilies)
          .each { |smiley| @smiley_map[smiley] = ":#{emoji}:" }
      end
    end
  end
end
