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

class CIMI::Model::Address < CIMI::Model::Base

  text :ip

  text :hostname

  text :allocation

  text :default_gateway

  text :dns

  text :mac_address

  text :protocol

  text :mask

  href :network

  href :resource

  array :operations do
    scalar :rel, :href
  end

  def self.find(id, context)
    if id==:all
      context.driver.addresses(context.credentials, {:env=>context})
    else
      context.driver.addresses(context.credentials, {:id=>id, :env=>context})
    end
  end

  def self.create(request_body, context, type)
    input = (type == :xml)? XmlSimple.xml_in(request_body, {"ForceArray"=>false, "NormaliseSpace"=>2}) : JSON.parse(request_body)
    if input["addressTemplate"]["href"] #by reference
      address_template = CIMI::Model::AddressTemplate.find(context.href_id(input["addressTemplate"]["href"], :address_templates), context)
    else
      case type
        when :json
          address_template = CIMI::Model::AddressTemplate.from_json(JSON.generate(input["addressTemplate"]))
        when :xml
          xml = XmlSimple.xml_in(request_body, {"NormaliseSpace"=>2})
          address_template = CIMI::Model::AddressTemplate.from_xml(XmlSimple.xml_out(xml["addressTemplate"][0]))
      end
    end
    params = {:name=>input["name"], :description=>input["description"], :address_template=>address_template, :env=>context }
    raise CIMI::Model::BadRequest.new("Bad request - missing required parameters. Client sent: #{request_body} which produced #{params.inspect}")  if params.has_value?(nil)
    context.driver.create_address(context.credentials, params)
  end

  def self.delete!(id, context)
    context.driver.delete_address(context.credentials, id)
  end

end
