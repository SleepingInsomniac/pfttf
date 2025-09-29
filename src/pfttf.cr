require "log"

module PFTTF
  VERSION = {% `shards version`.chomp.stringify %}
  Log = ::Log.for(self)
end

require "./pfttf/enums"
require "./pfttf/glyph"
require "./pfttf/reader"
