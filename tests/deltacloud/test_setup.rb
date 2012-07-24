#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

require 'rubygems'
require 'minitest/autorun'
require 'rest_client'
require 'nokogiri'
require 'json'
require 'base64'
require 'yaml'
require 'singleton'

#SETUP
topdir = File.join(File.dirname(__FILE__), '..')
$:.unshift topdir

module RestClient::Response
  def xml
    @xml ||= Nokogiri::XML(body)
  end

  def json
    @json ||= JSON.parse(body)
  end
end

module Deltacloud
  module Test

    class Config

      include Singleton

      def initialize
        fname = ENV["CONFIG"] || File::join(File::dirname(__FILE__), "..",
                                            "config.yaml")
        @hash = YAML.load(File::open(fname))
      end

      def url
        @hash["api_url"]
      end

      def basic_auth(u = nil, p = nil)
        u ||= @hash[driver]["user"]
        p ||= @hash[driver]["password"]
        "Basic #{Base64.encode64("#{u}:#{p}")}"
      end

      def driver
        xml.root[:driver]
      end

      def drivers
        @drivers ||= RestClient.get(url+"/drivers").xml.xpath("//driver/name").map { |c| c.text.downcase }
      end

      def version
        xml.root[:version]
      end

      def collections
        xml.xpath("//api/link").map { |c| c[:rel].to_sym }
      end

      def features
        result = {}
        xml.xpath("//api/link").each do |coll|
          result[coll[:rel].to_sym] = coll.xpath("feature").map { |c| c[:name].to_sym }
        end
        result
      end

      private
      def xml
        unless @xml
          @xml = RestClient.get(url).xml
          drv = @xml.root[:driver]
          unless @hash[drv]
            raise "No config for #{drv} driver in config.yaml used by #{url}"
          end
          unless @hash[drv]["user"] && @hash[drv]["password"]
            raise "No user or password in config.yaml for #{drv} driver used by #{url}"
          end
        end
        @xml
      end
    end

    def self.config
      Config::instance
    end
  end
end

module Deltacloud::Test::Methods

  module Global
    # Return the current test config; we call that 'api' since it looks a
    # little prettier in the tests
    def api
      Deltacloud::Test::config
    end

    # Make a GET request for +path+ and return the +RestClient::Response+. The
    # query string for the request is generated from +params+, with the
    # exception of a few special entries in params, which are used to set some
    # headers, and will not appear in the query string:
    #
    #   :noauth          : do not send an auth header
    #   :user, :password : use these for the auth header
    #   :accept          : can be :xml or :json, and sets the Accept header
    #   :driver, :provider : set driver and/or provider with the appropriate header
    #
    # If none of the auth relevant params are set, use the username and
    # password for the current driver from the config
    def get(path, params={})
      url, headers = process_url_params(path, params)
      RestClient.get url, headers
    end

    def post(path, post_body, params={})
      url, headers = process_url_params(path, params)
      RestClient.post url, post_body, headers
    end

    def delete(path, params={})
      url, headers = process_url_params(path, params)
      RestClient.delete url, headers
    end

    def options(path, params={})
      url, headers = process_url_params(path, params)
      RestClient.options url, headers
    end

    def random_name
      name = rand(36**10).to_s(36)
      name.insert(0, "apitest")
    end

    private

    def process_url_params(path, params)
      path = "" if path == "/"
      headers = {}
      unless params.delete(:noauth)
        if params[:user]
          u = params.delete(:user)
          p = params.delete(:password)
          headers['Authorization'] = api.basic_auth(u, p)
        else
          headers['Authorization'] = api.basic_auth
        end
      end
      headers["X-Deltacloud-Driver"] = params.delete(:driver) if params[:driver]
      headers["X-Deltacloud-Provider"] = params.delete(:provider) if params[:providver]
      headers["Accept"] = "application/#{params.delete(:accept)}" if params[:accept]

      if path =~ /^https?:/
        url = path
      else
        url = api.url + path
      end
      url += "?" + params.map { |k,v| "#{k}=#{v}" }.join("&") unless params.empty?
      if ENV["LOG"] && ENV["LOG"].include?("requests")
        puts "GET #{url}"
        headers.each { |k, v| puts "#{k}: #{v}" }
      end
      [url, headers]
    end

  end

  module ClassMethods
    # Only run tests if collection +name+ is supported by current
    # driver. Use inside a 'describe' block. Tests that are not run because
    # of a missing collection are marked as skipped
    def need_collection(name)
      before :each do
        unless api.collections.include?(name.to_sym)
          skip "#{api.driver} doesn't support #{name}"
        end
      end
    end

    # Only run tests if collection +collection+ supports feature +name+ in
    # the current driver. Use inside a 'describe' block. Tests that are not
    # run because of a missing collection are marked as skipped
    def need_feature(collection, name)
      before :each do
        f = api.features[collection.to_sym]
        unless f && f.include?(name.to_sym)
          skip "#{collection} for #{api.driver} doesn't support #{name}"
        end
      end
    end
  end


  def self.included(base)
    base.extend ClassMethods
    base.extend Global
    base.send(:include, Global)
  end

end
