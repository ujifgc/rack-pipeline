require 'fileutils'

module RackPipeline
  module Processing
    def combine(sources, target)
      cache_target(sources, target) do |target_path|
        body = sources.inject('') do |all,(source,kind)|
          all << "/*!\n * #{source}\n */\n\n" + File.read(prepare_file(source, static_type(target))).encode('utf-8') + "\n\n"
        end
        File.write(target_path, body)
        target_path
      end
    end

    def compress(source, target)
      return source unless settings[:compress]
      cache_target(source, target) do |target_path|
        Compressing.process(source, target_path)
      end
    end

    def compile(source, target)
      cache_target(source, target) do |target_path|
        Compiling.process(source, target_path)
      end
    end
  end
end
