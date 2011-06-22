# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{twitter-stream}
  s.version = "0.1.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Vladimir Kolesnikov"]
  s.date = %q{2010-10-05}
  s.description = %q{Simple Ruby client library for twitter streaming API. Uses EventMachine for connection handling. Adheres to twitter's reconnection guidline. JSON format only.}
  s.summary = %q{Twitter realtime API client}
  s.homepage = %q{http://github.com/voloko/twitter-stream}
  s.email = %q{voloko@gmail.com}

  s.platform                  = Gem::Platform::RUBY
  s.rubygems_version          = %q{1.3.6}
  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = ["README.markdown"]

  s.add_runtime_dependency('eventmachine', ">= 0.12.8")
  s.add_runtime_dependency('simple_oauth', '~> 0.1.4')
  s.add_runtime_dependency('http_parser.rb', '~> 0.5.1')
  s.add_development_dependency('rspec', "~> 2.5.0")

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

