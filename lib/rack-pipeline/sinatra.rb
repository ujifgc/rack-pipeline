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
        case type.to_sym
        when :css
          %(<link href="#{request.script_name}/#{asset}" rel="stylesheet">)
        when :js
          %(<script src="#{request.script_name}/#{asset}"></script>)
        end
      end
    end
  end
end
