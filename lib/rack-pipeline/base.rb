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

    STATIC_TYPES  = { '.js' => :js,                      '.css' => :css       }.freeze
    CONTENT_TYPES = { '.js' => 'application/javascript', '.css' => 'text/css' }.freeze

    def assets_for(pipes, type, opts = {})
      Array(pipes).inject([]) do |all,pipe|
        all += Array(settings[:combine] ? "#{pipe}.#{type}" : assets[type][pipe].keys)
      end.compact.uniq
    end

    def initialize(app, *args)
      @generations = 0
      @assets = {}
      @settings = {
        :temp => nil,
        :compress => false,
        :combine => false,
        :bust_cache => false,
        :css => {
          :app => 'assets/**/*.css',
        },
        :js => {
          :app => 'assets/**/*.js',
        },
      }
      @settings.merge!(args.pop)  if args.last.kind_of?(Hash)
      ensure_temp_directory
      populate_pipelines
      @app = app
    end

    def inspect
      { :settings => settings, :assets => assets }
    end

    def call(env)
      @env = env
      env['rack-pipeline'] = self
      if file_path = prepare_pipe(env['PATH_INFO'])
        serve_file(file_path, env['HTTP_IF_MODIFIED_SINCE'])
      else
        @app.call(env)
      end
    rescue MustRepopulate
      populate_pipelines
      retry
    end

    private

    def busted?
      result = settings[:bust_cache] && @busted
      @busted = false
      result
    end

    def serve_file(file, mtime)
      headers = { 'Last-Modified' => File.mtime(file).httpdate }
      if mtime == headers['Last-Modified']
        [304, headers, []]
      else
        if busted?
          headers['Location'] = "#{@env['PATH_INFO']}?#{File.mtime(file).to_i}"
          [302, headers, []]
        else
          body = File.read file
          headers['Content-Type'] = "#{content_type(file)}; charset=#{body.encoding.to_s}"
          headers['Content-Length'] = File.size(file).to_s
          [200, headers, [body]]
        end
      end
    rescue Errno::ENOENT
      raise MustRepopulate
    end

    def static_type(file)
      if file.kind_of? String
        STATIC_TYPES[file] || STATIC_TYPES[File.extname(file)]
      else
        STATIC_TYPES.values.include?(file) && file
      end
    end

    def content_type(file)
      CONTENT_TYPES[File.extname(file)] || 'text'
    end

    def prepare_pipe(path_info)
      file = path_info.start_with?('/') ? path_info[1..-1] : path_info
      type = static_type(file)  or return nil
      unless ready_file = prepare_file(file, type)
        pipename = File.basename(file, '.*').to_sym
        if assets[type] && assets[type][pipename]
          ready_file = combine(assets[type][pipename], File.basename(file))
        end
      end
      compress(ready_file, File.basename(ready_file))  if ready_file
    rescue Errno::ENOENT
      raise MustRepopulate
    end

    def prepare_file(source, type)
      assets[type].each do |pipe,files|
        case files[source]
        when :raw
          return source
        when :source
          return compile(source, File.basename(source, '.*') + ".#{type}")
        end
      end
      nil
    end

    def file_kind(file)
      static_type(file) ? :raw : :source
    end

    def glob_files(globs)
      Array(globs).each_with_object({}) do |glob,all|
        Dir.glob(glob).sort.each do |file|
          all[file] = file_kind(file)
        end
      end
    end

    def populate_pipelines
      fail SystemStackError, 'too many RackPipeline generations'  if @generations > 5
      @generations += 1
      STATIC_TYPES.each do |extname,type|
        pipes = settings[type]
        assets[type] = {}
        pipes.each do |pipe, dirs|
          assets[type][pipe] = glob_files(dirs)
        end
      end
    end
  end
end
