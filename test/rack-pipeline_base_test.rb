require 'minitest_helper'
require 'rack/test'
require 'rack-pipeline/base'

describe RackPipeline::Base do
  SETTINGS_1 = {}
  SETTINGS_2 = {
    :compress => true,
    :js => {
      :coffee => 'assets/**/*.coffee',
    }
  }

  before do
    Dir.chdir File.dirname(__FILE__)
    @mockapp = MiniTest::Mock.new
    @mockapp.expect(:call, [200, {}, ['UNDERLYING APP RESPONSE']], [Hash])
    @r1 = Rack::MockRequest.new(RackPipeline::Base.new(@mockapp, SETTINGS_1.dup))
    @r2 = Rack::MockRequest.new(RackPipeline::Base.new(@mockapp, SETTINGS_2.dup))
  end

  it 'should pass to underlying app' do
    response = @r1.get('/')
    @mockapp.verify
  end

  it 'should pass to underlying app' do
    response = @r1.get('/assets/stylesheets/non-existing.css')
    @mockapp.verify
  end

  it 'should respond with combined css' do
    response = @r1.get('/app.css')
    response.body.must_include 'color: black'
    response.body.must_include 'color: white'
  end

  it 'should respond with combined js' do
    response = @r1.get('/app.js')
    response.body.must_include 'a = function'
    response.body.must_include 'b = function'
  end

  it 'should respond with single css' do
    response = @r1.get('/assets/javascripts/a.js')
    response.body.must_include 'a = function'
  end

  it 'should respond with single js' do
    response = @r1.get('/assets/stylesheets/a.css')
    response.body.must_include 'color: white'
  end

  it 'should have proper css content_type' do
    response = @r1.get('/assets/stylesheets/a.css')
    response.headers['Content-Type'].must_include 'text/css'
  end

  it 'should have proper js content_type' do
    response = @r1.get('/app.js')
    response.headers['Content-Type'].must_include 'application/javascript'
  end

  it 'should properly compile and compress coffeescript' do
    response = @r2.get('/coffee.js')
    response.body.must_include '=function('
  end

  after do
    FileUtils.rm_r( File.join( Dir.tmpdir, 'RackPipeline' ) )
  end
end
