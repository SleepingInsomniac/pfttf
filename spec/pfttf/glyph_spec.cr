require "../spec_helper"

include PFTTF

describe Glyph do
  describe "point inferrence" do
    it "Inserts inferred on curve points" do
      glyph = Glyph.new(0i16, 0i16, 0i16, 0i16, [[
        {PointFlag::None, 0, 0},
        {PointFlag::None, 10, 10},
      ]])

      glyph.contours.should eq([[
        {PointFlag::None, 0, 0},
        {PointFlag::OnCurve, 5, 5},
        {PointFlag::None, 10, 10},
        {PointFlag::OnCurve, 5, 5},
      ]])
    end

    it "Inserts inferred off curve points" do
      glyph = Glyph.new(0i16, 0i16, 0i16, 0i16, [[
        {PointFlag::OnCurve, 0, 0},
        {PointFlag::OnCurve, 10, 10},
      ]])

      glyph.contours.should eq([[
        {PointFlag::OnCurve, 0, 0},
        {PointFlag::None, 5, 5},
        {PointFlag::OnCurve, 10, 10},
        {PointFlag::None, 5, 5},
      ]])
    end
  end
end
