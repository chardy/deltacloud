require 'rubygems'
require 'logger'
require 'minitest/autorun'
require 'rack/test'
require 'nokogiri'
require 'pp'
require 'require_relative' if RUBY_VERSION < '1.9'

require 'singleton'

require_relative '../lib/deltacloud/api.rb'

ENV['RACK_ENV'] = 'test'

if ENV['COVERAGE']
  begin
    require 'simplecov'
  rescue LoadError
    warn "To generate code coverage you need to install 'simplecov' (gem install simplecov OR bundle)"
  end
end

def record_retries(name='', opts = {})
  opts[:before] = Proc.new { |r, &block|
    VCR.use_cassette("#{__name__}-#{name.empty? ? '' : "#{name}-"}#{r}", &block)
  }
  if VCR.configuration.default_cassette_options[:record] == :none
    opts[:time_between_retry] = 0
  end
  opts
end

include Rack::Test::Methods

def status; last_response.status; end
def headers; last_response.headers; end
def response_body; last_response.body; end
def xml; Nokogiri::XML(response_body); end
def json; JSON::parse(response_body); end
def formats; [ 'application/xml', 'application/json', 'text/html' ]; end
def root_url(url=''); Deltacloud.default_frontend.root_url + url; end

module Deltacloud
  module Test
    class Config
      include Singleton

      def initialize
        fname = ENV["CONFIG"] || File::expand_path("~/.deltacloud/config")
        begin
          @hash = YAML.load(File::open(fname))
        rescue Errno::ENOENT
          @hash = {}
        end
      end

      def credentials(driver)
        driver = driver.to_s
        if @hash.has_key?(driver)
          user = @hash[driver]["user"]
          password = @hash[driver]["password"]
        else
          user = "fakeuser"
          password = "fakepassword"
        end
        { :user => user, :password => password }
      end
    end

    def self.config
      Config::instance
    end
  end
end
