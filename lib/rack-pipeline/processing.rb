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
      cache_target(source, target) do |target_path|
        if settings[:compress] && defined?(Compressor)
          Compressor.process(source, target_path)
        else
          FileUtils.cp(source, target_path)
          target_path
        end
      end
    end

    def compile(source, target)
      cache_target(source, target) do |target_path|
        if defined?(Compiler)
          Compiler.process(source, target_path)
        else
          fail LoadError, "no compiler for #{source} => #{target}"
        end
      end
    end
  end
end
