require 'rubygems'
lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include?(lib_path)

gem 'rspec'
require 'spec'
require 'spec/mocks'

def fixture_path(path)
  File.join(File.dirname(__FILE__), '..', 'fixtures', path)
end

def read_fixture(path)
  File.read(fixture_path(path))
end