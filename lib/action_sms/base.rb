module ActionSms #:nodoc#

  class Base
    @@connection = nil

    class << self
      # Returns true if a connection that's accessible to this class has already
      # been opened.
      def connected?
        return !@@connection.nil?
      end

      # Returns the connection currently associated with the class. This can
      # also be used to "borrow" the connection to do work that is specific to
      # a particular SMS gateway.
      def connection
        raise ConnectionNotEstablished unless @@connection
        return @@connection
      end

      # Set the gateway connection for the class.
      def connection=(spec) #:nodoc:
        raise ConnectionNotEstablished unless spec
        @@connection = spec
      end

      # Establishes the connection to the SMS gateway. Accepts a hash as input
      # where the :adapter key must be specified with the name of a gateway
      # adapter (in lower-case)
      #
      #   ActionSms::Base.establish_connection(
      #     :adapter  => "clickatell",
      #     :username => "myusername",
      #     :password => "mypassword"
      #     :api_id   => "myapiid"
      #   )
      #
      # The exceptions AdapterNotSpecified, AdapterNotFound, and ArgumentError
      # may be returned.
      def establish_connection(config)
        unless config.key?(:adapter)
          raise AdapterNotSpecified, "#{config} adapter is not configured"
        end
        adapter_method = "#{config[:adapter]}_connection"
        unless respond_to?(adapter_method)
          raise AdapterNotFound,
                "configuration specifies nonexistent #{config[:adapter]} adapter"
        end
        self.connection = self.send(adapter_method, config)
      end

      def deliver(sms, options = {})
        connection.deliver(sms, options)
      end

      def delivery_request_successful?(delivery_request)
        connection.delivery_request_successful?(delivery_request)
      end

      def message_id(data)
        adapter_method_result(:message_id, data)
      end

      def message_text(params)
        adapter_method_result(:message_text, params)
      end

      def sender(params)
        adapter_method_result(:sender, params)
      end

      def service_url
        connection.service_url
      end

      def status(params)
        adapter_method_result(:status, params)
      end

      private
        def adapter_method_result(adapter_method, *args)
          result = connection.call(adapter_method, *args)
          unless result
            gateway_adapters = adapters(adapter_method)
            i = 0
            adapter = nil
            begin
              adapter = gateway_adapters[i]
              result = adapter.call(adapter_method, *args) if adapter
              i += 1
            end until result || adapter.nil?
          end
          result
        end

        def adapters(adapter_method)
          adapters = []
          instance_methods.each do |method|
            if method.to_s =~ /\_connection$/
              begin
                adapter = call(method)
              rescue
              end
              adapters << adapter if adapter && adapter.respond_to?(adapter_method)
            end
          end
          adapters
        end
    end
  end
end

