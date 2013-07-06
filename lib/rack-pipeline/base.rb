require 'time'

require 'rack-pipeline/version'
require 'rack-pipeline/caching'
require 'rack-pipeline/processing'

module RackPipeline
  class MustRepopulate < Exception; end
  class Base
    include Caching
    include Processing

    attr_accessor :assets, :settings

    STATIC_TYPES = { '.js' => :js, '.css' => :css }.freeze

    def assets_for( pipes, type, opts = {} )
      Array(pipes).inject([]) do |all,pipe|
        all += Array( combine? ? assets[type][pipe] : "#{pipe}.#{type}" )
      end.compact.uniq
    end

    def initialize(app, *args)
      @generations = 0
      @assets = {}
      @settings = {
        :temp => nil,
        :compress => false,
        :combine => false,
        :content_type => {
          '.css' => 'text/css',
          '.js' => 'application/javascript',
        },
        :root => 'assets',
        :css => {
          :app => '**/*.css',
        },
        :js => {
          :app => '**/*.js',
        },
      }
      @settings.merge!(args.pop)  if args.last.kind_of?(Hash)
      File.directory?(@settings[:root])  or fail Errno::ENOTDIR, @settings[:root]
      create_temp_directory
      populate_pipelines
      @app = app
    end

    def inspect
      { :settings => settings, :assets => @assets }
    end

    def call(env)
      env['rack-pipeline'] = self
      file_path = prepare_pipe(env['PATH_INFO'])
      if file_path
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

    def static_type( file )
      if file.kind_of? String
        STATIC_TYPES[file] || STATIC_TYPES[File.extname(file)]
      else
        STATIC_TYPES.values.include?(file) && file
      end
    end

    def prepare_pipe( path_info )
      file = path_info.partition('?').first.sub(/^\//,'')
      type = static_type(file)
      ready_file = get_or_compile(file, type)
      unless ready_file
        pipename = File.basename(file, '.*').to_sym
        if assets[type] && assets[type][pipename]
          ready_file = combine( assets[type][pipename], File.basename(file) )
        end
      end
      compress ready_file
    end

    def get_or_compile( source, type )
      result = nil
      assets[type].each do |pipe,files|
        result = case files[source]
        when :raw
          source
        when :source
          compile( source, File.basename(source, '.*') + ".#{type}" )
        end
        break  if result
      end
      result
    end

    def file_kind( file )
      static_type(file) ? :raw : :source
    end

    def extract_files( globs )
      Array(globs).each_with_object({}) do |glob,all|
        Dir.glob(File.join(settings[:root],glob)).sort.each do |file|
          all[file] = file_kind( file )
        end
      end
    end

    def populate_pipelines
      fail( SystemStackError, 'too many RackPipeline generations' )  if @generations > 5
      @generations += 1
      STATIC_TYPES.each do |extname,type|
        pipes = settings[type]
        assets[type] = {}
        pipes.each do |pipe, globs|
          assets[type][pipe] = extract_files(globs)
        end
      end
    end
  end
end
