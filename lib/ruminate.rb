require 'yaml'
require 'fileutils'

module Ruminate
  require 'ruminate/railtie' if defined?(Rails)

  def self.create_plugins(config_file, ruminate_dir, plugin_dir)
    FileUtils.mkdir_p(plugin_dir)
    config = YAML.load(File.read(config_file))
    ruminate_plugin = File.expand_path('../ruminate/plugin.rb', __FILE__)
    rumx_mount      = config['rumx_mount']   || ''
    username        = config['username']
    password        = config['password']
    host            = config['host']         || 'localhost'
    port            = config['port']         || 3000
    smtp_host       = config['smtp_host']    || 'localhost'
    ruby_shebang    = config['ruby_shebang'] || '/usr/bin/env ruby'

    Dir["#{ruminate_dir}/*.yml"].each do |plugin_config_file|
      plugin_basename = File.basename(plugin_config_file, '.*')
      plugin_config = YAML.load(File.read(plugin_config_file))
      replace_templates(plugin_config, ruminate_dir)
      plugin_config.each do |graph_category, graph_configs|
        graph_configs.each do |graph_config|
          raise "No plot\n#{graph_config.inspect}" unless graph_config[:plot]
          config_params = ''
          graph_config.each do |key, value|
            config_params += "#{key} #{value}\n" if key.to_s.start_with?('graph_')
          end
          config_params += "graph_category #{graph_category}\n" unless graph_config[:graph_category]
          graph_config[:plot].each_with_index do |field_hash, i|
            field_hash.each do |key, value|
              next if key == :field
              config_params += "field#{i}.#{key} #{value}\n"
            end
          end

          fields = graph_config[:plot].map {|field_hash| field_hash[:field]}
          query = graph_config[:query]
          alerts = graph_config[:alert] || []
          alerts.each do |alert|
            alert[:email] = config['email'][alert[:email]] if alert[:email].kind_of?(Symbol)
          end
          name = plugin_basename
          name += '_' + graph_config[:name] if graph_config[:name]
          puts "Creating #{name}"
          File.open(File.join(plugin_dir, name), 'w', 0755) do |f|
            f.write <<-EOS
#!#{ruby_shebang}

require '#{ruminate_plugin}'

ruminate(
    ARGV[0],
    '#{rumx_mount}',
    #{username && username.inspect},
    #{password && password.inspect},
    '#{host}',
    #{port},
    '#{smtp_host}',
    #{config_params.inspect},
    '#{query}',
    #{fields.inspect},
    #{alerts.inspect}
)
            EOS
          end
        end
      end
    end
  end

  def self.create_links(config_file, plugin_dir)
    config = YAML.load(File.read(config_file))
    munin_plugin_dir = config['munin_plugin_dir'] || '/etc/munin/plugins'
    full_plugin_dir = File.expand_path(plugin_dir)
    Dir["#{munin_plugin_dir}/*"].each do |plugin_file|
      next unless File.symlink?(plugin_file)
      dest = File.readlink(plugin_file)
      if File.dirname(dest).end_with?(plugin_dir)
        puts "Removing #{plugin_file}"
        FileUtils.rm_f(plugin_file)
      end
    end
    Dir["#{full_plugin_dir}/*"].each do |plugin_file|
      new_plugin_file = File.join(munin_plugin_dir, File.basename(plugin_file))
      puts "Creating link for #{new_plugin_file}"
      File.symlink(plugin_file, new_plugin_file)
    end
    #system '/etc/init.d/munin-node restart'
  end

  private

  def self.replace_templates(hash, ruminate_dir)
    read_hash = hash.dup
    read_hash.each do |key, value|
      if key == :template
        hash.delete(:template)
        add_template_to_hash(hash, ruminate_dir, value)
      else
        replace_value(value, ruminate_dir)
      end
    end
  end

  def self.add_template_to_hash(hash, ruminate_dir, template_value)
    variables = template_value.split
    template_name = variables.shift
    filename = File.join(ruminate_dir, 'templates', "#{template_name}.yml")
    unless File.exist?(filename)
      filename = File.expand_path("../../config/templates/#{template_name}.yml", __FILE__)
      raise "Could not find template #{template_name}.yml" unless File.exist?(filename)
    end
    child_hash = YAML.load(File.read(filename))
    raise "Template #{template_name}.yml is not a hash" unless child_hash.kind_of?(Hash)
    variable_hash = {}
    variables.each do |value|
      eq_i = value.index('=')
      raise "Invalid substitution value #{value}" unless eq_i
      variable_hash[value[0,eq_i]] = value[eq_i+1..-1]
    end
    replace_variables(child_hash, variable_hash)
    replace_templates(child_hash, ruminate_dir)
    hash.merge!(child_hash)
  end

  def self.replace_value(value, ruminate_dir)
    if value.kind_of?(Array)
      value.each {|sub_value| replace_value(sub_value, ruminate_dir)}
    elsif value.kind_of?(Hash)
      replace_templates(value, ruminate_dir)
    end
  end

  def self.replace_variables(value, variable_hash)
    if value.kind_of?(String)
      variable_hash.each do |variable, sub|
        value.gsub!("%#{variable}%", sub)
      end
    elsif value.kind_of?(Array)
      value.each {|sub_value| replace_variables(sub_value, variable_hash)}
    elsif value.kind_of?(Hash)
      value.each_value {|sub_value| replace_variables(sub_value, variable_hash)}
    end
  end
end
