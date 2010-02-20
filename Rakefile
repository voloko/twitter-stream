require 'rubygems'
gem 'rspec'
require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts = %w(-fs --color)
end
task :default => :spec

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "twitter-stream"
    gemspec.summary = "Twitter realtime API client"
    gemspec.description = "Simple Ruby client library for twitter streaming API. Uses EventMachine for connection handling. Adheres to twitter's reconnection guidline. JSON format only."
    gemspec.email = "voloko@gmail.com"
    gemspec.homepage = "http://github.com/voloko/twitter-stream"
    gemspec.authors = ["Vladimir Kolesnikov"]
    gemspec.add_dependency("eventmachine", [">= 0.12.8"])
    gemspec.add_development_dependency("rspec", [">= 1.2.8"])
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
