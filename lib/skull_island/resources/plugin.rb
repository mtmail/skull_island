# frozen_string_literal: true

module SkullIsland
  # Resource classes go here...
  module Resources
    # The Plugin resource class
    #
    # @see https://docs.konghq.com/0.14.x/admin-api/#plugin-object Plugin API definition
    class Plugin < Resource
      property :name
      property :enabled, type: :boolean
      # property :run_on  # 1.0.x only
      property :config, validate: true, preprocess: true, postprocess: true
      property :consumer_id, validate: true, preprocess: true, postprocess: true, as: :consumer
      property :route_id, validate: true, preprocess: true, postprocess: true, as: :route
      property :service_id, validate: true, preprocess: true, postprocess: true, as: :service
      property :created_at, read_only: true, postprocess: true

      def self.batch_import(data, verbose: false, test: false)
        raise(Exceptions::InvalidArguments) unless data.is_a?(Array)

        data.each_with_index do |resource_data, index|
          resource = new
          resource.name = resource_data['name']
          resource.enabled = resource_data['enabled']
          resource.config = resource_data['config'].deep_sort if resource_data['config']
          resource.delayed_set(:consumer, resource_data, 'consumer_id')
          resource.delayed_set(:route, resource_data, 'route_id')
          resource.delayed_set(:service, resource_data, 'service_id')
          resource.import_update_or_skip(index: index, verbose: verbose, test: test)
        end
      end

      def self.enabled_names(api_client: APIClient.instance)
        api_client.get("#{relative_uri}/enabled")['enabled_plugins']
      end

      def self.schema(name, api_client: APIClient.instance)
        api_client.get("#{relative_uri}/schema/#{name}")
      end

      def export(options = {})
        hash = {
          'name' => name,
          'enabled' => enabled?,
          'config' => config.deep_sort
        }
        hash['consumer_id'] = "<%= lookup :consumer, '#{consumer.username}' %>" if consumer
        hash['route_id'] = "<%= lookup :route, '#{route.name}' %>" if route
        hash['service_id'] = "<%= lookup :service, '#{service.name}' %>" if service
        [*options[:exclude]].each do |exclude|
          hash.delete(exclude.to_s)
        end
        [*options[:include]].each do |inc|
          hash[inc.to_s] = send(:inc)
        end
        hash.reject { |_, value| value.nil? }
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def modified_existing?
        return false unless new?

        # Find plugins of the same name
        same_name = self.class.where(:name, name)
        return false if same_name.size.zero?

        same_name_and_consumer = same_name.where(:consumer, consumer)
        same_name_and_route = same_name.where(:route, route)
        same_name_and_service = same_name.where(:service, service)
        existing = if same_name_and_consumer.size == 1
                     same_name_and_consumer.first
                   elsif same_name_and_route.size == 1
                     same_name_and_route.first
                   elsif same_name_and_service.size == 1
                     same_name_and_service.first
                   end
        if existing
          @entity['id'] = existing.id
          save
        else
          false
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      private

      def preprocess_config(input)
        input.deep_sort
      end

      def postprocess_config(value)
        value.deep_sort
      end

      # TODO: 1.0.x requires refactoring as `consumer_id` becomes `consumer`
      def postprocess_consumer_id(value)
        if value.is_a?(Hash)
          Consumer.new(
            entity: value,
            lazy: true,
            tainted: false
          )
        elsif value.is_a?(String)
          Consumer.new(
            entity: { 'id' => value },
            lazy: true,
            tainted: false
          )
        else
          value
        end
      end

      # TODO: 1.0.x requires refactoring as `consumer_id` becomes `consumer`
      def preprocess_consumer_id(input)
        if input.is_a?(Hash)
          input['id']
        elsif input.is_a?(Consumer)
          input.id
        else
          input
        end
      end

      # TODO: 1.0.x requires refactoring as `route_id` becomes `route`
      def postprocess_route_id(value)
        if value.is_a?(Hash)
          Route.new(
            entity: value,
            lazy: true,
            tainted: false
          )
        elsif value.is_a?(String)
          Route.new(
            entity: { 'id' => value },
            lazy: true,
            tainted: false
          )
        else
          value
        end
      end

      # TODO: 1.0.x requires refactoring as `route_id` becomes `route`
      def preprocess_route_id(input)
        if input.is_a?(Hash)
          input['id']
        elsif input.is_a?(Route)
          input.id
        else
          input
        end
      end

      # TODO: 1.0.x requires refactoring as `service_id` becomes `service`
      def postprocess_service_id(value)
        if value.is_a?(Hash)
          Service.new(
            entity: value,
            lazy: true,
            tainted: false
          )
        elsif value.is_a?(String)
          Service.new(
            entity: { 'id' => value },
            lazy: true,
            tainted: false
          )
        else
          value
        end
      end

      # TODO: 1.0.x requires refactoring as `service_id` becomes `service`
      def preprocess_service_id(input)
        if input.is_a?(Hash)
          input['id']
        elsif input.is_a?(Service)
          input.id
        else
          input
        end
      end

      # Used to validate {#config} on set
      def validate_config(value)
        # only Hashes are allowed
        value.is_a?(Hash)
      end

      # Used to validate {#consumer} on set
      def validate_consumer_id(value)
        # allow either a Consumer object or a Hash of a specific structure
        value.is_a?(Consumer) || value.is_a?(String)
      end

      # Used to validate {#route} on set
      def validate_route_id(value)
        # allow either a Route object or a Hash of a specific structure
        value.is_a?(Route) || value.is_a?(String)
      end

      # Used to validate {#service} on set
      def validate_service_id(value)
        # allow either a Service object or a Hash of a specific structure
        value.is_a?(Service) || value.is_a?(String)
      end
    end
  end
end
