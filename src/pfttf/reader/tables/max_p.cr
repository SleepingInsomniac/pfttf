module PFTTF
  class Reader
    module Tables
      record MaxP,
        version : Float64,                 # 0x00010000 (1.0)
        num_glyphs : UInt16,               # the number of glyphs in the font
        max_points : UInt16,               # points in non-compound glyph
        max_contours : UInt16,             # contours in non-compound glyph
        max_component_points : UInt16,     # points in compound glyph
        max_component_contours : UInt16,   # contours in compound glyph
        max_zones : UInt16,                # set to 2
        max_twilight_points : UInt16,      # points used in Twilight Zone (Z0)
        max_storage : UInt16,              # number of Storage Area locations
        max_function_defs : UInt16,        # number of FDEFs
        max_instruction_defs : UInt16,     # number of IDEFs
        max_stack_elements : UInt16,       # maximum stack depth
        max_size_of_instructions : UInt16, # byte count for glyph instructions
        max_component_elements : UInt16,   # number of glyphs referenced at top level
        max_component_depth : UInt16       # levels of recursion, set to 0 if font has only simple glyphs
    end
  end
end
