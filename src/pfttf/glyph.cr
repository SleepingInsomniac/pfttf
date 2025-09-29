module PFTTF
  class Glyph
    getter x_min : Int16
    getter y_min : Int16
    getter x_max : Int16
    getter y_max : Int16

    getter contours : Array(Array(Tuple(PointFlag, Int32, Int32)))

    # Translation x, y | Relative Positioning (parent point index, child point index) | Affine transform (a, b, c, d) | Glyph
    getter components = Array(Tuple(Tuple(Int16, Int16), Tuple(UInt16, UInt16)?, Tuple(Float64, Float64, Float64, Float64), Glyph)).new

    def initialize(@x_min, @y_min, @x_max, @y_max, @contours)
      insert_inferred_points
    end

    # Inserts points where they are omitted for space saving (able to be inferred)
    private def insert_inferred_points
      @contours.map! do |contour|
        num_insertions = count_inferred_points(contour)
        with_inferred = Array(Tuple(PointFlag, Int32, Int32)).new(contour.size + num_insertions + 1)
        with_inferred << contour[0] if contour.size > 0
        contour.each_cons_pair do |a, b|
          f1, x1, y1 = a
          f2, x2, y2 = b
          if f1.on_curve? && f2.on_curve?
            # Insert an off curve point in between two points (straight line)
            with_inferred << {PointFlag::None, *mid_point(x1, y1, x2, y2)}
          elsif !f1.on_curve? && !f2.on_curve?
            # Insert an on curve point in between two points
            with_inferred << {PointFlag::OnCurve, *mid_point(x1, y1, x2, y2)}
          end
          with_inferred << {f2, x2, y2}
        end
        if contour[0]? && contour[-1]? && contour[0] != contour[-1]
          first, last = contour[0], contour[-1]
          if first[0].on_curve? && last[0].on_curve?
            with_inferred << {PointFlag::None, *mid_point(first[1], first[2], last[1], last[2])}
          elsif !first[0].on_curve? && !last[0].on_curve?
            with_inferred << {PointFlag::OnCurve, *mid_point(first[1], first[2], last[1], last[2])}
          end
        end
        with_inferred
      end
    end

    # Count the number of inferred points, in order to size our final array
    private def count_inferred_points(contour)
      num_insertions = 0
      contour.each_cons_pair do |a, b|
        f1, _x1, _y1 = a
        f2, _x2, _y2 = b
        num_insertions += 1 if (f1.on_curve? && f2.on_curve?) || (!f1.on_curve? && !f2.on_curve?)
      end
      num_insertions
    end

    # Linear interpolate at 0.5
    private def mid_point(x1, y1, x2, y2)
      x = (x2 - x1) * 0.5 + x1
      y = (y2 - y1) * 0.5 + y1
      {x.round.to_i, y.round.to_i}
    end
  end
end
