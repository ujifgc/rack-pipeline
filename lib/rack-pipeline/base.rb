require 'set'
require 'fileutils'
require 'time'
require 'digest/md5'

require 'rack-pipeline/version'

module RackPipeline
  class MustRepopulate < Exception; end
  class NeedCompiler < Exception; end
  class Base
    attr_accessor :assets, :static_assets, :dynamic_assets, :settings

    STATIC_TYPES = { '.js' => :js, '.css' => :css }.freeze

    def assets_for( pipes, type, opts = {} )
      Array(pipes).inject([]) do |all,pipe|
        all += Array( opts[:environment].to_s == 'development' ? assets[type][pipe] : "#{pipe}.#{type}" )
      end.compact.uniq
    end

    def initialize(app, *args)
      @settings = {
        :root => 'assets',
        :temp => temp_directory,
        :compress => false,
        :content_type => {
          '.css' => 'text/css',
          '.js' => 'application/javascript',
        },
        :css => {
          :app => '**/*.css',
        },
        :js => {
          :app => '**/*.js',
        },
      }
      @settings.merge!(args.pop)  if args.last.kind_of?(Hash)
      populate_pipelines
      @app = app
    end

    def inspect
      { :settings => settings, :assets => @assets }
    end

    def call(env)
      env['rack-pipeline'] = self
      @env = env
      if file_path = prepare_pipe(env['REQUEST_URI'])
        begin
          body = File.read file_path
          charset = "; charset=#{body.encoding.to_s}"
          time = File.mtime(file_path).httpdate
          headers = {}
          headers['Last-Modified'] = time
          if time == env['HTTP_IF_MODIFIED_SINCE']
            [304, headers, '']
          else
            headers['Content-Type'] = "#{settings[:content_type][File.extname(file_path)] || 'text'}#{charset}"
            headers['Content-Length'] = File.size(file_path).to_s
            [200, headers, body]
          end
        rescue Errno::ENOENT
          raise MustRepopulate
        end
      else
        @app.call(env)
      end
    rescue MustRepopulate
      populate_pipelines
      retry
    end

    private

    def compress?
      # TODO try to access env
      settings[:compress]
    end

    def static_type( file )
      if file.kind_of? String
        STATIC_TYPES[file] || STATIC_TYPES[File.extname(file)]
      else
        STATIC_TYPES.values.include?(file) && file
      end
    end

    def prepare_pipe( uri )
      file = uri.partition('?').first.gsub(/^#{@env['SCRIPT_NAME']}\/?/,'')
      type = static_type(file)
      ready_file = get_or_compile(file, type)
      pipename = File.basename(file, '.*').to_sym
      if !ready_file && assets[type] && assets[type][pipename]
        ready_file = combine( assets[type][pipename], File.basename(file) )
      end
      compress ready_file
    end

    def get_or_compile( file, type )
      case 
      when file.kind_of?(String) && static_assets.include?(file)
        file
      when file.kind_of?(Array) && dynamic_assets[file.first]
        compile( dynamic_assets[file.first], File.basename(file.first) )
      end
    end

    def cache_target( source, target )
      target_path = File.join( settings[:temp], target + mtime_hash(source) )
      if File.file?(target_path)
        target_path
      else
        cleanup_hash(target)
        yield target_path
      end
    end

    def combine( sources, target )
      cache_target( sources, target ) do |target_path|
        body = sources.inject('') do |all,source|
          file = get_or_compile(source, static_type(target))
          all << File.read(file).encode('utf-8') + "\n\n"
        end
        File.write( target_path, body )
        target_path
      end
    end

    def compile( source, target )
      cache_target( source, target ) do |target_path|
        compiled_file = if defined? Compiler
          Compiler.process source, target_path
        end
        raise NeedCompiler, "for #{source} => #{target}"  unless compiled_file
        compiled_file
      end
    end

    def compress( source )
      if compress? && defined?(Compressor)
        Compressor.process source
      else
        source
      end
    end

    def temp_directory
      tmp = if File.directory?('tmp')
        'tmp'
      else
        require 'tmpdir'
        Dir.tmpdir
      end
      tmp = File.join( tmp, 'RackPipeline' )
      FileUtils.mkdir_p tmp
      tmp
    end

    def cleanup_hash( target )
      FileUtils.rm Dir.glob( File.join( settings[:temp], target ) + '.*' )
    end

    def mtime_hash( sources )
      '.'+Digest::MD5.hexdigest(Array(sources).inject(''){|a,f| a<<"#{f}:#{File.mtime(Array(f).last)}"})
    rescue Errno::ENOENT
      raise MustRepopulate
    end

    def populate_pipelines
      @assets = {}
      @static_assets = Set.new
      @dynamic_assets = {}
      @settings.select{ |k,v| static_type(k) }.each do |type, pipes|
        assets[type] = {}
        pipes.each do |pipe, globs|
          assets[type][pipe] = []
          Array(globs).each do |glob|
            glob = File.join(settings[:root], glob)
            Dir.glob(glob).sort.each do |file|
              if static_type(file)
                assets[type][pipe] << file
                static_assets << file
              else
                compiled_file = File.join( File.dirname(file), File.basename(file, '.*') + ".#{type}")
                assets[type][pipe] << [ compiled_file, file ]
                dynamic_assets[compiled_file] = file
              end
            end
          end
        end
      end
      Logger 'NEW POPULATION', assets
    end

  end
end
