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
#

module Deltacloud
  module ExceptionHandler

    class DeltacloudException < StandardError

      attr_accessor :code, :name, :message, :backtrace, :request

      def initialize(code, name, message, backtrace, request=nil)
        @code, @name, @message = code, name, message
        @backtrace = backtrace
        @request = request
        self
      end

    end

    class AuthenticationFailure < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(401, e.class.name, message, e.backtrace)
      end
    end

    class ForbiddenError < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(403, e.class.name, message, e.backtrace)
      end
    end

    class UnknownMediaTypeError < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(406, e.class.name, message, e.backtrace)
      end
    end

    class MethodNotAllowed < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(405, e.class.name, message, e.backtrace)
      end
    end

    class ValidationFailure < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(400, e.class.name, message, e.backtrace)
      end
    end

    class BackendError < DeltacloudException
      def initialize(e, message=nil)
        message ||= e.message
        super(500, e.class.name, message, e.backtrace, message)
      end
    end

    class ProviderError < DeltacloudException
      def initialize(e, message)
        message ||= e.message
        super(502, e.class.name, message, e.backtrace)
      end
    end

    class ProviderTimeout < DeltacloudException
      def initialize(e, message)
        message ||= e.message
        super(504, e.class.name, message, e.backtrace)
      end
    end

    class NotImplemented < DeltacloudException
      def initialize(e, message)
        message ||= e.message
        super(501, e.class.name, message, e.backtrace)
      end
    end

    class ObjectNotFound < DeltacloudException
      def initialize(e, message)
        message ||= e.message
        super(404, e.class.name, message, e.backtrace)
      end
    end

    class NotSupported < DeltacloudException
      def initialize(message)
        super(501, self.class.name, message, self.backtrace)
      end
    end

    class ExceptionDef
      attr_accessor :status
      attr_accessor :message
      attr_reader   :conditions
      attr_reader   :handler

      def initialize(conditions, &block)
        @conditions = conditions
        instance_eval(&block) if block_given?
      end

      def status(code)
        self.status = code
      end

      def message(message)
        self.message = message
      end

      def exception(handler)
        self.handler = handler
      end

      # Condition can be class or regexp
      #
      def match?(e)
        @conditions.each do |c|
          return true if c.class == Class && e.class == c
          return true if c.class == Regexp && (e.class.name =~ c or e.message =~ c)
        end
        return false
      end

      def handler(e)
        return @handler if @handler
        case @status
          when 401 then Deltacloud::ExceptionHandler::AuthenticationFailure.new(e, @message)
          when 403 then Deltacloud::ExceptionHandler::ForbiddenError.new(e, @message)
          when 404 then Deltacloud::ExceptionHandler::ObjectNotFound.new(e, @message)
          when 406 then Deltacloud::ExceptionHandler::UnknownMediaTypeError.new(e, @message)
          when 405 then Deltacloud::ExceptionHandler::MethodNotAllowed.new(e, @message)
          when 400 then Deltacloud::ExceptionHandler::ValidationFailure.new(e, @message)
          when 500 then Deltacloud::ExceptionHandler::BackendError.new(e, @message)
          when 501 then Deltacloud::ExceptionHandler::NotImplemented.new(e, @message)
          when 502 then Deltacloud::ExceptionHandler::ProviderError.new(e, @message)
          when 504 then Deltacloud::ExceptionHandler::ProviderTimeout.new(e, @message)
        end
      end

    end

    class Exceptions
      attr_reader :exception_definitions

      def initialize(&block)
        @exception_definitions = []
        instance_eval(&block) if block_given?
        self
      end

      def on(*conditions, &block)
        @exception_definitions << ExceptionDef::new(conditions, &block) if block_given?
      end
    end

    def self.exceptions(&block)
      @definitions = Exceptions.new(&block).exception_definitions if block_given?
      @definitions
    end

    def safely(&block)
      begin
        block.call
      rescue
        report_method = $stderr.respond_to?(:err) ? :err : :puts
        Deltacloud::ExceptionHandler::exceptions.each do |exdef|
          if exdef.match?($!)
            new_exception = exdef.handler($!)
            m = (new_exception && !new_exception.message.nil?) ? new_exception.message : $!.message
            unless ENV['RACK_ENV'] == 'test'
              $stderr.send(report_method, "#{[$!.class.to_s, m].join(':')}\n#{$!.backtrace[0..10].join("\n")}")
            end
            raise exdef.handler($!) unless new_exception.nil?
          end
        end
        $stderr.send(report_method, "[NO HANDLED] #{[$!.class.to_s, $!.message].join(': ')}\n#{$!.backtrace.join("\n")}")
        raise Deltacloud::ExceptionHandler::BackendError.new($!, "Unhandled exception or status code (#{$!.message})")
      end
    end

  end

end
