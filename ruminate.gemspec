Gem::Specification.new do |s|
  s.name        = "ruminate"
  s.summary     = 'Easy generation of munin plugins to monitor your app'
  s.description = 'Simple process for generating munin plugins to monitor your Rails application'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/ruminate'
  s.files       = Dir["{lib}/**/*"] + %w(LICENSE.txt Rakefile History.md README.md)
  s.version     = '0.0.2'
  s.add_dependency 'rumx', '>= 0.1.1'
end
