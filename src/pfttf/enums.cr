module PFTTF
  # cmap 'platforms'
  enum Platform : UInt16
    Unicode
    Macintosh
    Reserved
    Microsoft
  end

  enum LocaIndexFormat : Int16
    Short
    Long
  end

  @[Flags]
  enum PointFlag : UInt8
    OnCurve
    XShort
    YShort
    Repeat
    XSame
    YSame
  end

  @[Flags]
  enum GlyphFlags : UInt16
    Words              # If set, the arguments are words; If not set, they are bytes.
    XYValues           # If set, the arguments are xy values; If not set, they are points.
    RoundXYToGrid      # If set, round the xy values to grid; if not set do not round xy values to grid (relevant only to bit 1 is set)
    WeHaveAScale       # If set, there is a simple scale for the component. If not set, scale is 1.0.
    NotUsed            # (this bit is obsolete)
    MoreComponents     # If set, at least one additional glyph follows this one.
    WeHaveAnXAndYScale # If set the x direction will use a different scale than the y direction.
    WeHaveATwoByTwo    # If set there is a 2-by-2 transformation that will be used to scale the component.
    WeHaveInstructions # If set, instructions for the component character follow the last component.
    UseMyMetrics       # Use metrics from this component for the compound glyph.
    OverlapCompound    # If set, the components of this compound glyph overlap
  end
end
