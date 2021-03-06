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

class CIMI::Model::AddressTemplate < CIMI::Model::Base

  text :ip

  text :hostname

  text :allocation

  text :default_gateway

  text :dns

  text :mac_address

  text :protocol

  text :mask

  href :network

  array :operations do
    scalar :rel, :href
  end

  def self.find(id, context)
    if id==:all
      context.driver.address_templates(context.credentials, {:env=>context})
    else
      context.driver.address_templates(context.credentials, {:id=>id, :env=>context})
    end
  end

  def self.create(request_body, context, type)
  end

  def self.delete!(id, context)
  end

end
