module I18n
  module JS
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        @cache = nil
        validate_cache!
        @app.call(env)
      end

      private
      def cache_path
        @cache_path ||= cache_dir.join("i18n-js.yml")
      end

      def cache_dir
        @cache_dir ||= Rails.root.join("tmp/cache")
      end

      def cache
        @cache ||= begin
          if cache_path.exist?
            YAML.load_file(cache_path) || {}
          else
            {}
          end
        end
      end

      def save_cache(new_cache)
        # path could be a symbolic link
        FileUtils.mkdir_p(cache_dir) unless File.exists?(cache_dir)
        File.open(cache_path, "w+") do |file|
          file << new_cache.to_yaml
        end
      end

      def config_file_path
        @config_file_path ||= Rails.root.join(::I18n::JS.config_file_path).to_s
      end

      # Check if translations should be regenerated.
      # ONLY REGENERATE when these conditions are met:
      #
      # # Cache file doesn't exist
      # # Translations and cache size are different (files were removed/added)
      # # Translation file has been updated
      #
      def validate_cache!
        valid_cache = []
        new_cache = {}

        valid_cache.push cache_path.exist?
        valid_cache.push ::I18n.load_path.uniq.size == cache.size - 1

        ::I18n.load_path.each do |path|
          changed_at = File.mtime(path).to_i
          valid_cache.push changed_at == cache[path]
          new_cache[path] = changed_at
        end

        if File.exist?(config_file_path)
          config_changed_at = File.mtime(config_file_path).to_i
        else
          config_changed_at = nil
        end
        valid_cache.push config_changed_at == cache[config_file_path]
        new_cache[config_file_path] = config_changed_at

        ::I18n::JS.configured_segments.each do |segment|
          valid_cache.push Rails.root.join(segment.file).exist?
        end

        return if valid_cache.all?

        save_cache(new_cache)

        ::I18n::JS.export
      end
    end
  end
end
