module RackPipeline
  module Sinatra
    def self.registered(app)
      app.use RackPipeline::Base, app.respond_to?(:pipeline) ? app.pipeline : {}
      app.helpers Helpers
    end

    module Helpers
      def pipeline(pipes = [ :app ], types = [ :css, :js ], options = {})
        bust_cache = respond_to?(:settings) && settings.respond_to?(:pipeline) && settings.pipeline[:bust_cache]
        @pipeline_object = env['rack-pipeline']
        Array(types).map do |type|
          assets = @pipeline_object.assets_for(pipes, type, options)
          assets.map do |asset|
            pipe_tag(type, asset + options[:postfix].to_s, bust_cache)
          end.join("\n")
        end.join("\n")
      end

      def pipe_tag(type, asset, bust_cache=nil)
        asset += cache_buster(asset) if bust_cache
        case type.to_sym
        when :css
          %(<link href="#{request.script_name}/#{asset}" rel="stylesheet">)
        when :js
          %(<script src="#{request.script_name}/#{asset}"></script>)
        end
      end

      def cache_buster(file)
        compress = respond_to?(:settings) && settings.respond_to?(:pipeline) && settings.pipeline[:compress]
        if !compress && File.file?(file)
          "?#{File.mtime(file).to_i}"
        else
          temp = @pipeline_object.ensure_temp_directory
          max_mtime = 0
          Dir.glob(File.join(temp, File.basename(file,'.*') << '.*' << File.extname(file))).each do |cached_file|
            mtime = File.mtime(cached_file).to_i
            max_mtime = mtime if mtime > max_mtime
          end
          max_mtime = Time.now.to_i if max_mtime == 0
          "?#{max_mtime}"
        end
      end
    end
  end
end
