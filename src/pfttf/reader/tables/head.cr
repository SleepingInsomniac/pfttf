module PFTTF
  class Reader
    module Tables
      record Head,
        version : Float32,
        font_revision : Float32,
        checksum_adjustment : UInt32,
        magic_number : UInt32,
        flags : UInt16,
        units_per_em : UInt16,
        created : Time,
        modified : Time,
        x_min : Int16,
        y_min : Int16,
        x_max : Int16,
        y_max : Int16,
        mac_style : UInt16,
        lowest_rec_ppem : UInt16,
        font_direction_hint : UInt16,
        index_to_loc_format : LocaIndexFormat,
        glyph_data_format : Int16
    end
  end
end
