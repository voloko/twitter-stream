# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{twitter-stream}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Vladimir Kolesnikov"]
  s.date = %q{2009-10-11}
  s.description = %q{Simple Ruby client library for twitter streaming API. Uses EventMachine for connection handling. Adheres to twitter's reconnection guidline. JSON format only.}
  s.email = %q{voloko@gmail.com}
  s.extra_rdoc_files = [
    "README.markdown"
  ]
  s.files = [
    "README.markdown",
     "Rakefile",
     "VERSION",
     "examples/reader.rb",
     "fixtures/twitter/basic_http.txt",
     "lib/twitter/json_stream.rb",
     "spec/spec_helper.rb",
     "spec/twitter/json_stream.rb"
  ]
  s.homepage = %q{http://github.com/voloko/twitter-stream}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{Twitter realtime API client}
  s.test_files = [
    "spec/spec_helper.rb",
     "spec/twitter/json_stream.rb",
     "examples/reader.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
