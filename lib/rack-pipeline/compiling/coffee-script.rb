require 'coffee-script'

module RackPipeline
  module Compiling
    module CoffeeScript
      def self.process(source, target)
        compiled = ::CoffeeScript.compile File.read(source)
        File.write(target, compiled)
        target
      end
    end
  end
end
