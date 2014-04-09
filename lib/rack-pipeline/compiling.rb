module RackPipeline
  module Compiling
    def self.process(source, target)
      ext = File.extname source
      if compiler = compilers[ext]
        require compiler[1]
        Compiling.const_get(compiler[0]).process(source, target)
      else
        fail LoadError, "no compiler for #{source} => #{target}"
      end
    end

    def self.register(ext, klass, feature)
      compilers[ext] = [klass, feature]
    end

    def self.compilers
      @compilers ||= {}
    end
  end
end

RackPipeline::Compiling.register '.coffee', 'CoffeeScript', 'rack-pipeline/compiling/coffee-script'
