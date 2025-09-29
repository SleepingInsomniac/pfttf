require "pixelfaucet/game"
require "pixelfaucet/controller"

require "./src/pfttf"
Log.setup(:debug)

class FontTest < PF::Game
  include PF
  include PF2d

  @reader = PFTTF::Reader.open("./fonts/Lora-Regular.ttf")
  @cap_height : Int16
  @x_height : Int16
  @origin : Vec2(Float64)
  @point_size = 72

  LINE_COLOR = Pixel.new(25, 25, 25)
  FONT_COLOR = Pixel.new(100, 100, 100)

  def initialize(*args, **kwargs)
    super(*args, **kwargs)

    @cap_height = @reader.glyph('X').y_max
    @x_height = @reader.glyph('x').y_max

    y = (@reader.head.y_max * scale_factor(@point_size)).to_i32
    @origin = Vec[10.0, 10.0 + y]

    @controller = PF::Controller(Keys).new({
      Keys::A     => "shrink",
      Keys::S     => "grow",
      Keys::UP    => "move up",
      Keys::DOWN  => "move down",
      Keys::LEFT  => "move left",
      Keys::RIGHT => "move right",
    })
    plug_in @controller
  end

  def pixel_size(point_size, ppi = 72)
    (point_size * ppi / 72).to_i
  end

  def scale_factor(point_size, ppi = 72)
    pixel_size(point_size, ppi) / @reader.head.units_per_em
  end

  def update(dt : Float64)
    @point_size += 10.0 * dt if @controller.held?("grow")
    @point_size -= 10.0 * dt if @controller.held?("shrink")
    speed = 50.0
    @origin = (@origin + Vec[speed, 0.0] * dt) if @controller.held?("move right")
    @origin = (@origin + Vec[-speed, 0.0] * dt) if @controller.held?("move left")
    @origin = (@origin + Vec[0.0, -speed] * dt) if @controller.held?("move up")
    @origin = (@origin + Vec[0.0, speed] * dt) if @controller.held?("move down")
  end

  def draw_ttf(string : String, origin, fill : PF::Pixel)
    x = origin.x

    string.chars.each do |char|
      case char
      when ' '
        origin.x = (origin.x + @reader.hor_metrics(char).advance_width * scale_factor(@point_size)).to_i32
      when '\n'
        origin.x = x
        origin.y += pixel_size(@point_size)
      else
        glyph = @reader.glyph(char)
        draw_glyph(glyph, origin, fill)
        origin.x = (origin.x + @reader.hor_metrics(char).advance_width * scale_factor(@point_size)).to_i32
      end
    end
  end

  def draw_glyph(glyph, origin, fill : PF::Pixel)
    tl = Vec[glyph.x_min, -glyph.y_min] * scale_factor(@point_size)
    br = Vec[glyph.x_max, -glyph.y_max] * scale_factor(@point_size)

    splines = glyph.contours.map do |contour|
      QuadSpline.new(contour.map { |(_, x, y)| origin + Vec[x, -y] * scale_factor(@point_size) })
    end

    @screen.fill_splines(splines, fill)

    offset = Vec[0, 1.5 * @cap_height * scale_factor(@point_size)]

    glyph.components.each do |position, relative_point, affine, glyph_component|
      draw_glyph(glyph_component, origin + (Vec[position[0], position[1]] * scale_factor(@point_size)), fill)
    end

    # splines.each do |spline|
    #   @screen.draw_spline(spline, Pixel.new(100, 100, 100), closed: true)
    # end
  end

  def draw
    clear

    ch = (@origin.y - (@cap_height * scale_factor(@point_size))).to_i32
    xh = (@origin.y - (@x_height * scale_factor(@point_size))).to_i32

    draw_line(0, ch, width, ch, LINE_COLOR)
    draw_line(0, xh, width, xh, LINE_COLOR)
    draw_line(0, @origin.y.to_i32, width, @origin.y.to_i32, LINE_COLOR)
    draw_ttf("ABCDEFGHIJKLM\nNOPQRSTUVWXYZ\nabcdefghijklm\nnopqrstuvwxyz", @origin, FONT_COLOR)
  end
end

FontTest.new(800, 400, 1).run!
