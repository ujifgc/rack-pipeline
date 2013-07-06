require 'minitest_helper'
require 'rack-pipeline'

describe RackPipeline do
  it 'should have a version' do
    RackPipeline::VERSION.must_match /.+/
  end
end
