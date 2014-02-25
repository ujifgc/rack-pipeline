require 'fileutils'

module RackPipeline
  module Processing
    def combine?
      settings[:combine]
    end

    def combine(sources, target)
      cache_target(sources, target) do |target_path|
        body = sources.inject('') do |all,(source,kind)|
          all << File.read(get_or_compile(source, static_type(target))).encode('utf-8') + "\n\n"
        end
        File.write(target_path, body)
        target_path
      end
    end

    def compress(source, target)
      return source unless settings[:compress] && defined?(Compressor)
      cache_target(source, target) do |target_path|
        Compressor.process(source, target_path)
      end
    end

    def compile(source, target)
      fail LoadError, "no compiler for #{source} => #{target}" unless defined?(Compiler)
      cache_target(source, target) do |target_path|
        Compiler.process(source, target_path)
      end
    end
  end
end
