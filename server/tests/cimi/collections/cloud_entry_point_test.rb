require 'rubygems'
require 'require_relative' if RUBY_VERSION < '1.9'

require 'minitest/autorun'
require_relative './common.rb'

describe CIMI::Collections::CloudEntryPoint do

  before do
    def app; CIMI::API; end
    @collection = CIMI::Collections.collection(:cloudEntryPoint)
  end

  it 'has index operation' do
    @collection.operation(:index).must_equal Sinatra::Rabbit::CloudentrypointCollection::IndexOperation
  end

  it 'set the CIMI-Version header' do
    get root_url
    headers['CIMI-Specification-Version'].wont_be_nil
    headers['CIMI-Specification-Version'].must_equal '1.0.0'
  end

  it 'advertise CIMI collections in XML format' do
    get root_url + '/cloudEntryPoint'
    xml.root.name.must_equal 'CloudEntryPoint'
    (xml.root/'description').first.text.wont_be_empty
    (xml.root/'id').first.text.wont_be_empty
  end

  it 'advertise CIMI collections in JSON format' do
    get root_url + '/cloudEntryPoint?format=json'
    json.wont_be_empty
    json['description'].wont_be_empty
    json['id'].wont_be_empty
  end

  it 'allow to force authentication using force_auth parameter in URI' do
    get root_url + '/cloudEntryPoint?force_auth=1'
    status.must_equal 401
    authorize 'mockuser', 'mockpassword'
    get root_url + '/cloudEntryPoint?force_auth=1'
    status.must_equal 200
  end

  it 'advertise only supported CIMI collections by driver' do
    header 'X-Deltacloud-Driver', 'ec2'
    get root_url + '/cloudEntryPoint'
    (xml/'CloudEntryPoint/routingGroups').must_be_empty
    header 'X-Deltacloud-Driver', 'mock'
    get root_url + '/cloudEntryPoint'
    (xml/'CloudEntryPoint/routingGroups').wont_be_empty
  end

end
