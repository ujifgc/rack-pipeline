module RackPipeline
  module Processing
    def combine?
      settings[:combine]
    end

    def compress?
      settings[:compress]
    end

    def combine( sources, target )
      cache_target( sources, target ) do |target_path|
        body = sources.inject('') do |all,(source,kind)|
          all << File.read(get_or_compile(source, static_type(target))).encode('utf-8') + "\n\n"
        end
        File.write( target_path, body )
        target_path
      end
    end

    def compress( source )
      if compress? && defined?(Compressor)
        Compressor.process source
      else
        source
      end
    end

    def compile( source, target )
      cache_target( source, target ) do |target_path|
        compiled_file = if defined? Compiler
          Compiler.process source, target_path
        end
        raise LoadError, "compiler for #{source} => #{target}"  unless compiled_file
        compiled_file
      end
    end
  end
end
