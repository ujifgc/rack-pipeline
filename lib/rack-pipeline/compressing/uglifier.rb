require 'uglifier'

module RackPipeline
  module Compressing
    module Uglifier
      def self.process(source, target)
        compiled = ::Uglifier.compile File.read(source)
        File.write(target, compiled)
        target
      end
    end
  end
end
