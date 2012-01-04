require 'net/http'
require 'cgi'
require 'net/smtp'
require 'etc'
require 'socket'

def send_email(smtp_host, to, subject, message)
  from = "#{Etc.getlogin}@#{Socket.gethostname}"
  msg = <<-EOM
To: <#{to}>
From: <#{from}>
Subject: #{subject}

#{message}
  EOM

  Net::SMTP.start(smtp_host) do |smtp|
    smtp.send_message msg, from, to
  end
end

def ruminate(arg0, rumx_mount, username, password, host, port, smtp_host, config_params, query, fields, alerts)
  if arg0 == 'config'
    puts config_params
    return
  end

  # Args can be of the form Myfolder/Subfolder/Foo?reset=true which will expand to <mount>/attributes.<format>?query0=Myfolder/Subfolder/Foo/attributes?reset=true&query1=etc
  path = rumx_mount + '/attributes.properties?'
  query.split.each_with_index do |query_part, index|
    path += '&' if index > 0
    path += "query_#{index}=#{CGI.escape(query_part)}"
  end

  req = Net::HTTP::Get.new(path)
  req.basic_auth(username, password) if username
  res = Net::HTTP.start(host, port) { |http| http.request(req) }
  if res.kind_of?(Net::HTTPSuccess)
    result_hash = {}
    res.body.split("\n").each do |line|
      if (i = line.index('=')) >= 0
        value = line[(i+1)..-1]
        # TODO: Necessary to do an integer check?
        value = value.to_f if value.match(/^\s*[+-]?((\d+_?)*\d+(\.(\d+_?)*\d+)?|\.(\d+_?)*\d+)(\s*|([eE][+-]?(\d+_?)*\d+)\s*)$/)
        result_hash[line[0,i]] = value
      end
    end
    fields.each_with_index do |field_name, i|
      puts "field#{i}.value #{result_hash[field_name]}"
    end
    alerts.each do |alert|
      filter = String.new(alert[:filter])
      result_hash.each do |field_name, value|
        filter.gsub!(Regexp.new("\\b#{field_name.gsub('.', '\\.')}\\b"), value.inspect)
      end
      status = false
      begin
        if eval(filter)
          filter = String.new(alert[:filter])
          result_hash.each do |field_name, value|
            filter.gsub!(Regexp.new("\\b#{field_name.gsub('.', '\\.')}\\b"), "#{field_name}(#{value})")
          end
          message = <<-EOM
The following filter has been triggered:

#{filter}
          EOM
          send_email(smtp_host, alert[:email], "ALERT: #{alert[:title]}", message)
        end
      rescue Exception => e
        message = <<-EOM
The following filter caused an exception #{e.message}:

Original Filter: #{alert[:filter]}
Evaled Filter:   #{filter}
        EOM
        send_email(smtp_host, alert[:email], "ALERT EXCEPTION: #{alert[:title]}", message)
      end
    end
  end
end
