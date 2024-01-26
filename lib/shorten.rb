Dir[File.join(File.dirname(__FILE__), 'shorten', '*')].each do |file|
  require File.realpath(file)
end

module Shorten; end
