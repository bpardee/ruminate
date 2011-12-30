require 'ruminate'

namespace :ruminate do

  desc "create Munin plugins"
  task :create_plugins do
    Ruminate.create_plugins('config/ruminate.yml', 'config/ruminate', 'config/ruminate_plugins')
  end

  desc 'Create links for the Munin plugins (This should be run as sudo)'
  task :create_links do
    Ruminate.create_links('config/ruminate.yml', 'config/ruminate', 'config/ruminate_plugins')
  end
end
