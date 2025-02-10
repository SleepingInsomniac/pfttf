module PFTTF
  class Reader
    module Tables
      # struct Hhea
      #   def self.from_io
      #     Hhea.new()
      #   end
      # end
      record Hhea,
        version : Float32,              # 0x00010000 (1.0)
        ascent : Int16,                 # Distance from baseline of highest ascender
        descent : Int16,                # Distance from baseline of lowest descender
        line_gap : Int16,               # typographic line gap
        advance_width_max : UInt16,     # must be consistent with horizontal metrics
        min_left_side_bearing : Int16,  # must be consistent with horizontal metrics
        min_right_side_bearing : Int16, # must be consistent with horizontal metrics
        x_max_extent : Int16,           # max(lsb + (x_max-x_min))
        caret_slope_rise : Int16,       # used to calculate the slope of the caret (rise/run) set to 1 for vertical caret
        caret_slope_run : Int16,        # 0 for vertical
        caret_offset : Int16,           # set value to 0 for non-slanted fonts
        _res1 : Int16,
        _res2 : Int16,
        _res3 : Int16,
        _res4 : Int16,
        metric_data_format : Int16,      # 0 for current format
        num_of_long_hor_metrics : UInt16 # number of advance widths in metrics table
    end
  end
end
