require 'ruminate'
require 'rails'
module Ruminate
  class Railtie < Rails::Railtie
    railtie_name :ruminate

    rake_tasks do
      load "tasks/ruminate.rake"
    end
  end
end
