require 'digest/md5'
require 'fileutils'

module RackPipeline
  module Caching
    def cache_target( source, target )
      target_path = File.join( settings[:temp], "#{File.basename(target)}.#{calculate_hash(source)}#{File.extname(target)}" )
      if File.file?(target_path)
        target_path
      else
        cleanup_cache(target)
        yield target_path
      end
    end

    def create_temp_directory
      temp = if settings[:temp]
        settings[:temp]
      else
        require 'tmpdir'
        File.join( Dir.tmpdir, 'RackPipeline' )
      end
      FileUtils.mkdir_p temp
      settings[:temp] = temp
    end

    def cleanup_cache( target )
      FileUtils.rm Dir.glob( File.join( settings[:temp], File.basename(target) ) + '.*' )
    end

    def calculate_hash( sources )
      Digest::MD5.hexdigest(Array(sources).inject(''){ |all,(file,_)| all << "#{file}:#{File.mtime(file)}" })
    end
  end
end
