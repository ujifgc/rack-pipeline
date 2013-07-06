require 'minitest_helper'

describe RackPipeline do
  it 'should have a version' do
    RackPipeline::VERSION.must_match /.+/
  end
end
