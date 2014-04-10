require 'digest/md5'
require 'fileutils'

module RackPipeline
  module Caching
    def cache_target(source, target)
      ensure_temp_directory
      caller_method = caller.first[/`([^']*)'/, 1]
      extname = File.extname(target)
      target_filename = File.basename(target).sub(/[0-9a-f]{32}\./,'').chomp(extname) << '.' << caller_method
      target_path = File.join(settings[:temp], target_filename + '.' << calculate_hash(source) << extname)
      if File.file?(target_path)
        target_path
      else
        cleanup_cache(target_filename << '.*' << extname)
        yield target_path
      end
    end

    def ensure_temp_directory
      temp = settings[:temp]
      return temp if temp.kind_of?(String) && File.directory?(temp)
      unless temp
        require 'tmpdir'
        temp = File.join(Dir.tmpdir, 'RackPipeline')
      end
      FileUtils.mkdir_p temp
      settings[:temp] = temp
    end

    def cleanup_cache(target)
      @busted = true
      FileUtils.rm Dir.glob(File.join(settings[:temp], target))
    end

    def calculate_hash(sources)
      Digest::MD5.hexdigest(Array(sources).inject(''){ |all,(file,_)| all << file << File.mtime(file).to_i.to_s })
    end
  end
end
