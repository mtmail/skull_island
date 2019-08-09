# frozen_string_literal: true

module SkullIsland
  # Resource classes go here...
  module Resources
    # The Certificate resource class
    #
    # @see https://docs.konghq.com/1.1.x/admin-api/#certificate-object Certificate API definition
    class Certificate < Resource
      include Helpers::Meta

      property :cert, required: true, validate: true
      property :key, required: true, validate: true
      property :snis, validate: true
      property :created_at, read_only: true, postprocess: true
      property :tags, validate: true, preprocess: true, postprocess: true

      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def self.batch_import(data, verbose: false, test: false, project: nil, time: nil)
        raise(Exceptions::InvalidArguments) unless data.is_a?(Array)

        known_ids = []

        data.each_with_index do |resource_data, index|
          resource = new
          resource.delayed_set(:cert, resource_data, 'cert')
          resource.delayed_set(:key, resource_data, 'key')
          resource.snis = resource_data['snis'] if resource_data['snis']
          resource.tags = resource_data['tags'] if resource_data['tags']
          resource.project = project if project
          resource.import_time = (time || Time.now.utc.to_i) if project
          resource.import_update_or_skip(index: index, verbose: verbose, test: test)
          known_ids << resource.id
        end

        cleanup_except(project, known_ids) if project
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      def export(options = {})
        hash = { 'cert' => cert, 'key' => key }
        hash['snis'] = snis if snis && !snis.empty?
        hash['tags'] = tags unless tags.empty?
        [*options[:exclude]].each do |exclude|
          hash.delete(exclude.to_s)
        end
        [*options[:include]].each do |inc|
          hash[inc.to_s] = send(inc.to_sym)
        end
        hash.reject { |_, value| value.nil? }
      end

      def modified_existing?
        return false unless new?

        # Find certs of the same cert and key
        same_key = self.class.where(:key, key)

        existing = same_key.size == 1 ? same_key.first : nil

        if existing
          @entity['id'] = existing.id
          save
        else
          false
        end
      end

      private

      # Used to validate {#cert} on set
      def validate_cert(value)
        # only String is allowed
        value.is_a?(String)
      end

      # Used to validate {#key} on set
      def validate_key(value)
        # only String is allowed
        value.is_a?(String)
      end

      # Used to validate {#snis} on set
      def validate_snis(value)
        return false unless value.is_a?(Array)

        # allow only valid hostnames
        value.each do |sni|
          return false unless sni.match?(host_regex) && !sni.match?(/_/)
        end
        true
      end
    end
  end
end
