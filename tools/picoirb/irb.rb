#! /usr/bin/env ruby

if RUBY_ENGINE == "ruby"
  require_relative "./shell.rb"
end

Shell.new.start(:mrbsh)
