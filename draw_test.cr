require "./src/pfttf"

PPI        = 72
POINT_SIZE = 50

class PFTF < PF::Game
  include PF
  include PF2d

  # @reader = PFTTF::Reader.open("./Zapfino.ttf")
  @reader = PFTTF::Reader.open("./OpenSans-Regular.ttf")
  # @reader = PFTTF::Reader.open("./Monaco.ttf")
  @scale_factor : Float64
  @pixel_size : Int32

  COLORS = [
    Pixel::Red,
    Pixel::Green,
    Pixel::Blue,
    Pixel::Yellow,
    Pixel::Cyan,
    Pixel::Magenta,
  ]

  def initialize(*args, **kwargs)
    super(*args, **kwargs)

    @pixel_size = (POINT_SIZE * PPI / 72).to_i
    @scale_factor = @pixel_size / @reader.head.units_per_em

    puts "Scale Factor: #{@scale_factor}"
    @reader.hmtx
    # puts @glyph_data
  end

  def update(dt : Float64)
  end

  def draw_ttf(string : String, origin)
    x = origin.x

    string.chars.each do |char|
      case char
      when ' '
        origin.x = (origin.x + @reader.hor_metrics(char).advance_width * @scale_factor).to_i32
      when '\n'
        origin.x = x
        origin.y += @pixel_size
      else
        glyph = @reader.glyph(char)
        draw_glyph(glyph, origin)
        origin.x = (origin.x + @reader.hor_metrics(char).advance_width * @scale_factor).to_i32
      end
    end
  end

  def draw_glyph(glyph, origin)
    fill_circle(origin, 2, Pixel.new(20, 20, 20))

    tl = Vec[glyph.x_min, -glyph.y_min] * @scale_factor
    br = Vec[glyph.x_max, -glyph.y_max] * @scale_factor

    # draw_rect(origin + tl, origin + br, Pixel.new(15, 15, 15))

    glyph.contours.each_with_index do |contour, ci|
      spline = QuadSpline.new(contour.map { |c| origin + Vec[c[1], -c[2]] * @scale_factor })
      @screen.draw_spline(spline, COLORS[ci % COLORS.size], closed: true)
    end

    glyph.contours.each do |contour|
      contour.each_with_index do |(flags, x, y), i|
        p1 = Vec[x, -y] * @scale_factor

        if flags.on_curve?
          fill_circle(origin + p1, 1, Pixel.new(255, 255, 255))
        else
          draw_circle(origin + p1, 1, Pixel.new(100, 100, 100))
        end
      end
    end

    glyph.components.each do |position, relative_point, affine, glyph_component|
      # draw_glyph(glyph_component, origin + position)
      draw_glyph(glyph_component, origin + (Vec[position[0], position[1]] * @scale_factor))
    end
  end

  def draw
    clear

    # origin = Vec[10, (height // 3) * 2]
    origin = Vec[10, 20 + @pixel_size]
    draw_line(0, origin.y, width, origin.y, Pixel.new(10, 10, 10))
    draw_ttf("Héllô, World!", origin)
    # draw_ttf("Hello, World!", origin)
    # draw_ttf("ABCDEFGHIJKLM\nNOPQRSTUVWXYZ\nabcdefghijklm\nnopqrstuvwxyz", origin)
  end
end

PFTF.new(800, 480, 2).run!
