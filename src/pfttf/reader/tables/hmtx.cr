module PFTTF
  class Reader
    module Tables
      # https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6hmtx.html
      struct Hmtx
        record LongHorMetric, advance_width : UInt16, left_side_bearing : Int16

        def self.from_io(io : IO, num_of_long_hor_metrics : Number, num_glyphs : Number)
          lhms = Array(LongHorMetric).new(num_of_long_hor_metrics) do
            LongHorMetric.new(io.read_bytes(UInt16, ByteOrder), io.read_bytes(Int16, ByteOrder))
          end

          Hmtx.new(lhms)
        end

        getter long_hor_metrics : Array(LongHorMetric)

        def initialize(@long_hor_metrics)
        end
      end
    end
  end
end
