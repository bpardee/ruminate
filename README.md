# ruminate

http://github.com/ClarityServices/ruminate

## Description:

Easily generate munin plugins to monitor and provide email alerts for your site.

## Install:

  gem install ruminate

## Usage:

Refer to https://github.com/ClarityServices/rumx for information on setting up Rumx Beans and a Rumx mount for your application.

Create a file config/ruminate.yml that might look as follows:

    rumx_mount:       /rumx
    username:         myusername
    password:         mypassword
    host:             localhost
    port:             3000
    smtp_host:        localhost
    ruby_shebang:     /usr/bin/env ruby
    munin_plugin_dir: /etc/munin/plugins
    email:
      :techstaff:  techstaff@acme.com otherpeople@acme.com
      :my_test:    myemail@acme.com

Add Rumx beans for the parts of the app that you want to monitor.  For instance, you might add the following lines to app/models/my_model.rb:

    class MyModel
      @@timer = Rumx::Beans::TimerAndError.new
      Rumx::Bean.root.add_child(:Timer, @@timer)
      ...
      def my_expensive_and_error_prone_operation
        @@timer.measure do
          ... expensive, possible exception-raising stuff here
        end
      end
    end

Create a directory config/ruminate and put yaml files representing the monitoring that you want to perform.  For instance,
you might create the file config/ruminate/my_model.yml that looks as follows:

    MyModel:
      - :name: times
        :query: Timer?reset=true
        :graph_title: MyModel Times
        :graph_args: --base 1000 -l 0
        :graph_vlabel: msec
        :graph_info: This graph monitors the times for MyModels expensive operation.
        :plot:
          - :label: avg
            :info: Average time of request
            :draw: LINE
            :field: avg_time
          - :label: min
            :info: Min time of request
            :draw: LINE
            :field: min_time
          - :label: max
            :info: Max time of request
            :draw: LINE
            :field: max_time
        :alert:
          - :title: MyModel average times exceeded their threshold
            :filter: avg_time > 1000
            :email: :techstaff
      - :name: counts
        :query: Timer
        :graph_title: MyModel Total and Error counts
        :graph_vlabel: count
        :graph_info: This graph shows the total counts and errors for MyModel.
        :plot:
          - :label: total
            :info: Total count of requests
            :draw: LINE
            :field: total_count
          - :label: errors
            :info: Total requests that created an exception
            :draw: LINE
            :field: error_count
        :alert:
          - :title: MyModel failures exceeded threshold
            :filter: error_count > 20
            :email: :techstaff

When you deploy, perform the following:

    rake ruminate:create_plugins
    sudo rake ruminate:create_links

## TODO

Too much repitition.  Create templates for plot stuff in timers, etc.

Probably need to modify rumx bean to not reset error counts.  Use trending for info.

Make sure the example above actually works.

## Author

Brad Pardee

## Copyright

Copyright (c) 2011 Clarity Services. See LICENSE for details.
