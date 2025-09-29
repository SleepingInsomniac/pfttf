require "./reader/table_header"
require "./reader/tables/*"

# require "./reader/code_map_4"

module PFTTF
  class Reader
    alias ByteOrder = IO::ByteFormat::BigEndian

    def self.open(path : String)
      Reader.new(File.open(path, "r"))
    end

    getter io : IO

    getter scalar_type : UInt32
    getter num_tables : UInt16
    getter search_range : UInt16
    getter entry_selector : UInt16
    getter range_shift : UInt16

    getter bitmap_only : Bool = false

    getter tables = Hash(String, TableHeader).new
    # getter cmap_tables = Hash(Tuple(Platform, UInt16), CodeMap4).new

    # getter glyphs = Hash(Tuple(UInt32, Platform, UInt16), Glyph).new
    getter glyphs = Hash(UInt32, Glyph).new

    def initialize(@io)
      # Font directory / offsets
      @scalar_type = @io.read_bytes(UInt32, ByteOrder)
      @num_tables = @io.read_bytes(UInt16, ByteOrder)
      @search_range = @io.read_bytes(UInt16, ByteOrder)
      @entry_selector = @io.read_bytes(UInt16, ByteOrder)
      @range_shift = @io.read_bytes(UInt16, ByteOrder)

      tag_buf = Bytes.new(4)
      @num_tables.times do
        @io.read_fully(tag_buf)
        @tables[String.new(tag_buf)] = TableHeader.new(
          @io.read_bytes(UInt32, ByteOrder),
          @io.read_bytes(UInt32, ByteOrder),
          @io.read_bytes(UInt32, ByteOrder),
        )
      end

      Log.debug { "Tables:" }
      @tables.each do |tag, table|
        Log.debug { "  #{tag}" }
      end
    end

    # 16-bit signed fraction
    def read_short_frac(io : IO)
      (io.read_bytes(Int16, ByteOrder) / 0x4000_i16).round(5)
    end

    # 16.16-bit signed fixed-point number
    def read_fixed(io : IO)
      Float32.new((io.read_bytes(Int32, ByteOrder) / (UInt16::MAX // 2)))
    end

    def read_fword(io : IO)
      io.read_bytes(Int16, ByteOrder)
    end

    def read_ufword(io : IO)
      io.read_bytes(UInt16, ByteOrder)
    end

    def read_date(io : IO)
      span = io.read_bytes(Int64, ByteOrder)
      Time.utc(1904, 1, 1, 0, 0, 0) + span.seconds
    end

    def read_f2_14(io : IO)
      io.read_bytes(Int16, ByteOrder) / 16384.0 # 2 ^ 14
    end

    # 'head' table
    getter head : Tables::Head do
      table = if t = @tables["head"]?
                Log.debug { "Reading head" }
                @bitmap_only = false
                t
              else
                Log.debug { "Reading bhed" }
                @bitmap_only = true
                @tables["bhed"]
              end

      @io.seek(table.offset)
      h = Tables::Head.new(
        read_fixed(@io),
        read_fixed(@io),
        @io.read_bytes(UInt32, ByteOrder),
        @io.read_bytes(UInt32, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        read_date(@io),
        read_date(@io),
        read_fword(@io),
        read_fword(@io),
        read_fword(@io),
        read_fword(@io),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        LocaIndexFormat.new(@io.read_bytes(Int16, ByteOrder)),
        @io.read_bytes(Int16, ByteOrder),
      )
      Log.debug { h }
      h
    end

    def bhed
      head
    end

    # Represents the character map 'cmap' table
    # subtables are lazy loaded from the parsed subtable header information
    getter cmap : Tables::Cmap do
      Tables::Cmap.from_io(@io, @tables["cmap"])
    end

    # Location 'loca' table - Contains the offset for the glyph by cmap glph index
    getter loca : Array(UInt32) do
      Log.debug { "Reading loca" }
      num_glyphs = maxp.num_glyphs
      Log.debug { " ↳ glyphs: #{num_glyphs}" }
      index_to_loc_format = head.index_to_loc_format
      Log.debug { " ↳ format: #{index_to_loc_format}" }

      table = @tables["loca"]
      @io.seek(table.offset)

      case index_to_loc_format
      when LocaIndexFormat::Short
        Array(UInt32).new(num_glyphs + 1) { @io.read_bytes(UInt16, ByteOrder).to_u32 * 2 }
      when LocaIndexFormat::Long
        Array(UInt32).new(num_glyphs + 1) { @io.read_bytes(UInt32, ByteOrder) }
      else
        raise "Wrong index to loc format: #{index_to_loc_format}"
      end
    end

    # 'maxp' table - contains info about max memory requirements
    getter maxp : Tables::MaxP do
      Log.debug { "Reading maxp" }
      table = @tables["maxp"]
      @io.seek(table.offset)

      Tables::MaxP.new(
        read_fixed(@io),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
        @io.read_bytes(UInt16, ByteOrder),
      )
    end

    # Horizontal head
    getter hhea : Tables::Hhea do
      Log.debug { "Reading hhea" }
      table = @tables["hhea"]
      @io.seek(table.offset)
      Tables::Hhea.new(
        read_fixed(@io),                  # version Fixed 0x00010000 (1.0)
        read_fword(@io),                  # ascent FWord Distance from baseline of highest ascender
        read_fword(@io),                  # descent FWord Distance from baseline of lowest descender
        read_fword(@io),                  # lineGap FWord typographic line gap
        read_ufword(@io),                 # advanceWidthMax uFWord must be consistent with horizontal metrics
        read_fword(@io),                  # minLeftSideBearing FWord must be consistent with horizontal metrics
        read_fword(@io),                  # minRightSideBearing FWord must be consistent with horizontal metrics
        read_fword(@io),                  # xMaxExtent FWord max(lsb + (xMax-xMin))
        @io.read_bytes(Int16, ByteOrder), # caretSlopeRise int16 used to calculate the slope of the caret (rise/run) set to 1 for vertical caret
        @io.read_bytes(Int16, ByteOrder), # caretSlopeRun int16 0 for vertical
        read_fword(@io),                  # caretOffset FWord set value to 0 for non-slanted fonts
        @io.read_bytes(Int16, ByteOrder), # reserved int16 set value to 0
        @io.read_bytes(Int16, ByteOrder), # reserved int16 set value to 0
        @io.read_bytes(Int16, ByteOrder), # reserved int16 set value to 0
        @io.read_bytes(Int16, ByteOrder), # reserved int16 set value to 0
        @io.read_bytes(Int16, ByteOrder), # metricDataFormat int16 0 for current format
        @io.read_bytes(UInt16, ByteOrder) # numOfLongHorMetrics uint16 number of advance widths in metrics table
      )
    end

    # Herizontal metrics
    getter hmtx : Tables::Hmtx do
      Log.debug { "Reading hmtx" }
      num_glyphs = maxp.num_glyphs
      num_of_long_hor_metrics = hhea.num_of_long_hor_metrics
      table = @tables["hmtx"]
      @io.seek(table.offset)
      Tables::Hmtx.from_io(@io, num_of_long_hor_metrics, num_glyphs)
    end

    def hor_metrics(char : Char, platform : Platform = Platform::Unicode, platform_specific_id : UInt16? = nil)
      code_map = cmap[platform, platform_specific_id]
      code = UInt32::MAX & char.ord
      hmtx.long_hor_metrics[code_map[code]]? || Tables::Hmtx::LongHorMetric.new(0u16, 0i16)
    end

    # Get the glyph for a character based on provided encoding
    def glyph(char : Char, platform : Platform = Platform::Unicode, platform_specific_id : UInt16? = nil)
      glyph(char.ord, platform, platform_specific_id)
    end

    # Get the glyph for a code point based on provided encoding
    def glyph(code : Int32, platform : Platform = Platform::Unicode, platform_specific_id : UInt16? = nil)
      glyph(UInt32::MAX & code, platform, platform_specific_id)
    end

    def glyph(code : UInt32, platform : Platform = Platform::Unicode, platform_specific_id : UInt16? = nil)
      glyph_at_offset(glyph_offset(code, platform, platform_specific_id))
    end

    # Finds the offset for a given codepoint into the glyph table by using the cmap to get glyf into the loca table
    # for the offset into the glyph table
    def glyph_offset(code : UInt32, platform : Platform = Platform::Unicode, platform_specific_id : UInt16? = nil)
      code_map = cmap[platform, platform_specific_id]
      offset = loca[code_map[code]]? || 0u32
    end

    # Get the glyph for a code point based on provided encoding
    def glyph_at_offset(offset : UInt32, depth = 0)
      offset = @tables["glyf"].offset + offset

      return @glyphs[offset] if @glyphs[offset]?
      puts_padding = "  " * depth
      Log.debug { puts_padding + "Reading Glyph at offset: #{offset.to_s(16)}" }

      @io.seek(offset)

      num_contours = @io.read_bytes(Int16, ByteOrder)
      if num_contours == -1
        Log.debug { puts_padding + " ↳ Compound Glyph" }
      else
        Log.debug { puts_padding + " ↳ Contours: #{num_contours}" }
      end

      x_min = @io.read_bytes(Int16, ByteOrder)
      y_min = @io.read_bytes(Int16, ByteOrder)
      x_max = @io.read_bytes(Int16, ByteOrder)
      y_max = @io.read_bytes(Int16, ByteOrder)

      Log.debug { puts_padding + " ↳ min (#{x_min}, #{y_min}), max (#{x_max}, #{y_max})" }

      if num_contours < 0
        compound_glyph = Glyph.new(x_min, y_min, x_max, y_max, Array(Array(Tuple(PointFlag, Int32, Int32))).new(0))
        has_instructions = false

        loop do
          Log.debug { puts_padding + " -> Glyph Component:" }
          glyph_flags = GlyphFlags.new(@io.read_bytes(UInt16, ByteOrder))
          has_instructions ||= glyph_flags.we_have_instructions?
          Log.debug { puts_padding + " ↳ Flags: #{glyph_flags}" }
          glyph_index = @io.read_bytes(UInt16, ByteOrder)
          Log.debug { puts_padding + " ↳ Index: #{glyph_index}" }
          position = {0_i16, 0_i16}
          relative_point : Tuple(UInt16, UInt16)? = nil

          if glyph_flags.xy_values?
            # next two data points represent x and y translation offsets
            position = if glyph_flags.words?
                         {@io.read_bytes(Int16, ByteOrder), @io.read_bytes(Int16, ByteOrder)}
                       else
                         {@io.read_bytes(Int8, ByteOrder).to_i16, @io.read_bytes(Int8, ByteOrder).to_i16}
                       end
          else
            relative_point = if glyph_flags.words?
                               {@io.read_bytes(UInt16, ByteOrder), @io.read_bytes(UInt16, ByteOrder)}
                             else
                               {@io.read_bytes(UInt8, ByteOrder).to_u16, @io.read_bytes(UInt8, ByteOrder).to_u16}
                             end
          end

          a, b, c, d = 1.0, 0.0, 0.0, 1.0
          case glyph_flags
          when GlyphFlags::WeHaveAScale
            a = read_f2_14(@io)
            d = a
          when GlyphFlags::WeHaveAnXAndYScale
            a = read_f2_14(@io)
            d = read_f2_14(@io)
          when GlyphFlags::WeHaveATwoByTwo
            a = read_f2_14(@io)
            b = read_f2_14(@io)
            c = read_f2_14(@io)
            d = read_f2_14(@io)
          end

          affine = {a, b, c, d}

          Log.debug { puts_padding + " ↳ Position: #{position}" }
          Log.debug { puts_padding + " ↳ Relative Point: #{relative_point}" }
          Log.debug { puts_padding + " ↳ Affine: #{affine}" }

          pos = @io.pos
          glyph_component = glyph_at_offset(loca[glyph_index]? || 0u32, depth + 1)
          @io.seek(pos)

          compound_glyph.components << {position, relative_point, affine, glyph_component}

          break unless glyph_flags.more_components?
        end

        if has_instructions
          number_of_instructions = @io.read_bytes(UInt16, ByteOrder)
          Log.debug { puts_padding + " ↳ #{number_of_instructions} Instructions" }
          instructions = Array(UInt8).new(number_of_instructions) { @io.read_bytes(UInt8, ByteOrder) }
        end

        @glyphs[offset] = compound_glyph
      else
        end_points = Array(UInt16).new(num_contours) { @io.read_bytes(UInt16, ByteOrder) }
        instruction_length = @io.read_bytes(UInt16, ByteOrder)
        instructions = Array(UInt8).new(instruction_length) { @io.read_bytes(UInt8, ByteOrder) }

        num_points = end_points.last + 1 # the last endpoint index must be the number of points

        Log.debug { puts_padding + " ↳ Points: #{num_points}" }
        flags = Array(PointFlag).new(num_points)
        x_values = Array(Int32).new(num_points)
        y_values = Array(Int32).new(num_points)

        while flags.size < num_points
          flag = PointFlag.new(@io.read_bytes(UInt8, ByteOrder) & 0b0011_1111u8)
          flags << flag
          if flag.repeat?
            repeat_count = @io.read_bytes(UInt8, ByteOrder)
            repeat_count.times { flags << flag }
          end
        end

        x = 0
        flags.each_with_index do |flag, i|
          x += if flag.x_short?
                 @io.read_bytes(UInt8, ByteOrder).to_i16 * (flag.x_same? ? 1 : -1)
               else
                 flag.x_same? ? 0 : @io.read_bytes(Int16, ByteOrder)
               end
          x_values << x
        end

        y = 0
        flags.each_with_index do |flag, i|
          y += if flag.y_short?
                 @io.read_bytes(UInt8, ByteOrder).to_i16 * (flag.y_same? ? 1 : -1)
               else
                 flag.y_same? ? 0 : @io.read_bytes(Int16, ByteOrder)
               end
          y_values << y
        end

        points = flags.zip(x_values, y_values)
        pep = 0u16
        contours = Array(Array(Tuple(PointFlag, Int32, Int32))).new(num_contours) do |i|
          fep = end_points[i]? || points.size.to_u16
          c = points[pep..fep]
          pep = fep + 1
          c
        end

        @glyphs[offset] = Glyph.new(x_min, y_min, x_max, y_max, contours)
      end
    end

    def read_contours
    end
  end
end
