require 'yaml'
require 'fileutils'

module Ruminate
  require 'ruminate/railtie' if defined?(Rails)

  def self.create_plugins(config_file, ruminate_dir, plugin_dir)
    FileUtils.rm_rf(plugin_dir)
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
      plugin_config.each do |graph_category, graph_configs|
        graph_configs.each do |graph_config|
          config_params = ''
          graph_config.each do |key, value|
            config_params += "#{key} #{value}\n" if key.to_s.start_with?('graph_')
          end
          config_params += "graph_category #{graph_category}\n" unless graph_config[:graph_category]
          graph_config[:plot].each_with_index do |field_hash, i|
            field_hash.each do |key, value|
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
    plugin_dir = File.expand_path(plugin_dir)
    Dir["#{munin_plugin_dir}/*"].each do |plugin_file|
      next unless File.symlink?(plugin_file)
      dest = File.readlink(plugin_file)
      if dest.start_with?(plugin_dir)
        puts "Removing #{plugin_file}"
        FileUtils.rm(plugin_file)
      end
    end
    Dir["#{plugin_dir}/*"].each do |plugin_file|
      new_plugin_file = File.join(munin_plugin_dir, File.basename(plugin_file))
      puts "Creating link for #{new_plugin_file}"
      File.symlink(plugin_file, new_plugin_file)
    end
    #system '/etc/init.d/munin-node restart'
  end
end
