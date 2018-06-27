Gem::Specification.new do |s|
  s.name          = 'logstash-output-thetapoint'
  s.version       = '0.3.0'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Send data to ThetaPoint'
  s.description   = 'Send data to ThetaPoint using HTTPS to submit plain or compressed messages'
  s.homepage      = 'https://github.com/harryrh/logstash-output-thetapoint'
  s.authors       = ['Harry Halladay']
  s.email         = 'harry@theta-point.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_development_dependency "logstash-devutils"
end
