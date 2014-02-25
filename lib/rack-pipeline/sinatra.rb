module RackPipeline
  module Sinatra
    def self.registered(app)
      app.use RackPipeline::Base, app.respond_to?(:pipeline) ? app.pipeline : {}
      app.helpers Helpers
    end

    module Helpers
      def pipeline(pipes = [ :app ], types = [ :css, :js ], opts = {})
        Array(types).map do |type|
          assets = env['rack-pipeline'].assets_for(pipes, type, opts)
          assets.map do |asset|
            pipe_tag(type, asset)
          end.join("\n")
        end.join("\n")
      end

      def pipe_tag(type, asset)
        asset += cache_buster(asset)
        case type.to_sym
        when :css
          %(<link href="#{request.script_name}/#{asset}" rel="stylesheet">)
        when :js
          %(<script src="#{request.script_name}/#{asset}"></script>)
        end
      end

      def cache_buster(file)
        if File.file?(file)
          "?#{File.mtime(file).to_i}"
        else
          temp = if respond_to?(:settings) && settings.respond_to?(:pipeline) && settings.pipeline[:temp]
            settings.pipeline[:temp]
          else
            require 'tmpdir'
            File.join(Dir.tmpdir, 'RackPipeline')
          end
          mtimes = []
          Dir.glob(File.join(temp,file+'.*')).each do |cached_file|
            mtimes << File.mtime(cached_file).to_i
          end
          "?#{mtimes.max || Time.now.to_i}"
        end
      end
    end
  end
end
