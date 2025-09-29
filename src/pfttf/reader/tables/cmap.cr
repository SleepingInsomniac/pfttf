module PFTTF
  class Reader
    module Tables
      # https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
      class Cmap
        record SubtableHeader,
          platform : Platform,
          platform_specific_id : UInt16,
          offset : UInt32

        class Subtable
          record CodeRange,
            range : Range(UInt16, UInt16),
            id_delta : Int16,
            id_range_offset : UInt16

          property ranges = Array(CodeRange).new
          property glyph_indices : Array(UInt16)

          def initialize(@glyph_indices)
          end

          def <<(code_range : CodeRange)
            @ranges << code_range
          end

          def [](code_point)
            Log.trace { "Searching code point: #{code_point.to_s(16)}" }
            if index = @ranges.index { |code_range| code_range.range.covers?(code_point) }
              code_range = @ranges[index]

              if code_range.id_range_offset == 0
                Log.trace { " ↳ code_range.id_range_offset == 0" }
                code_point &+ code_range.id_delta
              else
                gi_index = code_range.id_range_offset // 2 +
                           (code_point - code_range.range.begin) -
                           (@ranges.size - index)

                glyph_index = @glyph_indices[gi_index]? || 0u16
                glyph_index = glyph_index &+ code_range.id_delta if glyph_index != 0
                glyph_index
              end
            else
              0u16
            end
          end
        end

        def self.from_io(io : IO, table_header : TableHeader)
          Log.debug { "Reading cmaps" }
          io.seek(table_header.offset)
          version = io.read_bytes(UInt16, ByteOrder)
          num_tables = io.read_bytes(UInt16, ByteOrder)
          subtable_headers = Array(SubtableHeader).new(num_tables) do
            platform = Platform.new(io.read_bytes(UInt16, ByteOrder))
            platform_specific_id = io.read_bytes(UInt16, ByteOrder)
            offset = io.read_bytes(UInt32, ByteOrder) + table_header.offset
            Log.debug { " ↳ #{platform}, #{platform_specific_id}, @#{offset.to_s(16)}" }
            SubtableHeader.new(platform, platform_specific_id, offset)
          end

          new(io, version, num_tables, subtable_headers)
        end

        property io : IO
        property version : UInt16
        property num_tables : UInt16
        property subtable_headers : Array(SubtableHeader)
        property subtables = Hash(SubtableHeader, Subtable).new

        def initialize(@io, @version, @num_tables, @subtable_headers)
        end

        def [](platform : Platform, platform_specific_id : UInt16? = nil)
          filtered_headers = subtable_headers.select { |h| h.platform == platform }
          raise "#{platform} not supported in font file!" if filtered_headers.empty?
          subtable_header = case platform
                            when Platform::Unicode
                              if psid = platform_specific_id
                                filtered_headers.find { |h| h.platform_specific_id == psid }
                              else
                                filtered_headers.sort_by(&.platform_specific_id).last
                              end
                            else
                              raise "Only unicode platform supported"
                            end

          raise "No subtable for #{platform}, #{platform_specific_id}" if subtable_header.nil?

          return @subtables[subtable_header] if @subtables[subtable_header]?

          @io.seek(subtable_header.offset)
          format = @io.read_bytes(UInt16, ByteOrder)
          subtable = case format
                     when 4 then parse_subtable_4(subtable_header)
                     else
                       raise "Unsupported cmap format #{format} for cmaps[#{platform};#{platform_specific_id}]"
                     end
          @subtables[subtable_header] = subtable
          subtable
        end

        def parse_subtable_4(subtable_header)
          Log.debug { "Parsing cmap subtable format 4" }
          length = @io.read_bytes(UInt16, ByteOrder) # Length in bytes
          Log.debug { " ↳ length: #{length}" }
          _language = @io.read_bytes(UInt16, ByteOrder) # Unused unless macintosh format (0 = adaptive)
          seg_count = @io.read_bytes(UInt16, ByteOrder) // 2
          Log.debug { " ↳ seg_count: #{seg_count}" }
          search_range = @io.read_bytes(UInt16, ByteOrder)
          Log.debug { " ↳ search_range: #{search_range}" }
          entry_selector = @io.read_bytes(UInt16, ByteOrder)
          Log.debug { " ↳ entry_selector: #{entry_selector}" }
          range_shift = @io.read_bytes(UInt16, ByteOrder)
          Log.debug { " ↳ range_shift: #{range_shift}" }
          end_codes = Array(UInt16).new(seg_count) { @io.read_bytes(UInt16, ByteOrder) }
          @io.read_bytes(UInt16, ByteOrder) # reserved pad
          start_codes = Array(UInt16).new(seg_count) { @io.read_bytes(UInt16, ByteOrder) }
          id_deltas = Array(Int16).new(seg_count) { @io.read_bytes(Int16, ByteOrder) }
          id_range_offsets = Array(UInt16).new(seg_count) { @io.read_bytes(UInt16, ByteOrder) }
          glyph_index_size = (length - (@io.pos - subtable_header.offset)) // 2
          Log.debug { " ↳ glyph_index_size: #{glyph_index_size}" }
          glyph_index_array = Array(UInt16).new(glyph_index_size) { @io.read_bytes(UInt16, ByteOrder) }

          subtable = Subtable.new(glyph_index_array)
          seg_count.times do |i|
            subtable << Subtable::CodeRange.new(start_codes[i]..end_codes[i], id_deltas[i], id_range_offsets[i])
          end

          subtable
        end
      end
    end
  end
end
