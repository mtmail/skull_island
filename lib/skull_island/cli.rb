# frozen_string_literal: true

# Internal requirements
require 'skull_island'

# External requirements
require 'yaml'
require 'thor'

module SkullIsland
  # Base CLI for SkullIsland
  class CLI < Thor
    class_option :verbose, type: :boolean

    desc 'export [OPTIONS] OUTPUT_FILE', 'Export the current configuration to OUTPUT_FILE'
    def export(output_file = '-')
      if output_file == '-'
        STDERR.puts '[INFO] Outputting to STDOUT' if options['verbose']
      else
        full_filename = File.expand_path(output_file)
        dirname = File.dirname(full_filename)
        unless File.exist?(dirname) && File.ftype(dirname) == 'directory'
          raise Exceptions::InvalidArguments, "#{full_filename} is invalid"
        end
      end

      output = { 'version' => '0.14' }

      [
        Resources::Consumer,
        Resources::Service,
        Resources::Upstream,
        Resources::Plugin
      ].each { |clname| export_class(clname, output) }

      if output_file == '-'
        STDOUT.puts output.to_yaml
      else
        File.write(full_filename, output.to_yaml)
      end
    end

    desc 'import [OPTIONS] INPUT_FILE', 'Import a configuration from INPUT_FILE'
    option :test, type: :boolean, desc: "Don't do anything, just show what would happen"
    def import(input_file = '-')
      raw ||= if input_file == '-'
                STDERR.puts '[INFO] Reading from STDOUT' if options['verbose']
                STDIN.read
              else
                full_filename = File.expand_path(input_file)
                unless File.exist?(full_filename) && File.ftype(full_filename) == 'file'
                  raise Exceptions::InvalidArguments, "#{full_filename} is invalid"
                end

                begin
                  File.read(full_filename)
                rescue StandardError => e
                  raise "Unable to process #{relative_path}: #{e.message}"
                end
              end

      # rubocop:disable Security/YAMLLoad
      input = YAML.load(raw)
      # rubocop:enable Security/YAMLLoad

      [
        Resources::Consumer,
        Resources::Service,
        Resources::Upstream,
        Resources::Plugin
      ].each { |clname| import_class(clname, input) }
    end

    private

    def export_class(class_name, output_data)
      STDERR.puts "[INFO] Processing #{class_name.route_key}" if options['verbose']
      output_data[class_name.route_key] = class_name.all.collect(&:export)
    end

    def import_class(class_name, import_data)
      STDERR.puts "[INFO] Processing #{class_name.route_key}" if options['verbose']
      class_name.batch_import(
        import_data[class_name.route_key],
        verbose: options['verbose'],
        test: options['test']
      )
    end
  end
end