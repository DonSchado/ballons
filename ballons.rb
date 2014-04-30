require 'gosu'

module Zindex
  Background, Ballons, Player, Clouds, UI = *0..4
end

class GameWindow < Gosu::Window
  attr_accessor :background_image, :fonts, :images, :player, :ballons, :timer, :game_over, :clouds

  def initialize
    super(1200, 900, false)
    self.caption = 'Ballons vs Unicorn'
    restart
    play_song
  end

  def set_timer
    Time.now.to_i + 11
  end

  def background
    self.background_image = game_over ? images[:endscreen] : images[:rainbow]
    background_image.draw(0, 0, Zindex::Background)
  end

  def images
    @images ||= {
      rainbow: Gosu::Image.new(self, "media/rainbow.jpg", true),
      endscreen: Gosu::Image.new(self, "media/endscreen.jpg", true),
    }
  end

  def fonts
    @fonts ||= {
      normal: Gosu::Font.new(self, Gosu::default_font_name, 20),
      big: Gosu::Font.new(self, Gosu::default_font_name, 100)
    }
  end

  def restart
    self.game_over = false
    self.player = Player.new(self)
    self.ballons = []
    self.timer = set_timer
    self.clouds = [Cloud.new(self, :left), Cloud.new(self, :right)]
  end

  def update
    if want_to_restart?
      restart
    elsif game_over
      return
    else
      move_player
      update_ballons
      handle_clouds
    end
    play_song
  end

  def handle_clouds
    if clouds.any? { |c| c.intersect?(player) }
      player.slow_down
    else
      player.normal_speed
    end
  end

  def update_ballons
    player.collect_ballons(ballons)
    if rand(100) < 4 && ballons.size < 25
      ballons.push(Ballon.new(self))
    end
  end

  def move_player
    if button_down?(Gosu::KbLeft) || button_down?(Gosu::GpLeft)
      player.turn_left
    end
    if button_down?(Gosu::KbRight) || button_down?(Gosu::GpRight)
      player.turn_right
    end
    if button_down?(Gosu::KbUp) || button_down?(Gosu::GpButton0)
      player.accelerate
    end
    player.move
  end

  def want_to_restart?
    button_down? Gosu::KbReturn
  end

  def time_over?
    timer <= Time.now.to_i
  end

  def draw
    if time_over?
      self.game_over = true
      draw_game_over
    else
      draw_game
      move_clouds
    end
  end

  def move_clouds
    clouds.each { |c| c.move }
    clouds.each { |c| c.draw }
  end

  def time_left
    fonts[:normal].draw(timer - Time.now.to_i, 1175, 2, Zindex::UI, 1.0, 1.0, 0xff5c00a1)
  end

  def draw_game
    time_left
    background
    player.draw
    ballons.each { |ballon| ballon.draw }
    fonts[:normal].draw("Score: #{player.score}", 2, 2, Zindex::UI, 1.0, 1.0, 0xff5c00a1)
  end

  def draw_game_over
    background
    fonts[:normal].draw("Your score is: #{player.score}", 400, 350, Zindex::UI, 2.0, 2.0, 0xfff72eff)
    fonts[:big].draw("Game Over", 320, 400, Zindex::UI, 1.0, 1.0, 0xffffffff)
    fonts[:normal].draw("press ESC to exit or hit ENTER to restart", 330, 500, Zindex::UI, 1.0, 1.0, 0xffffffff)
  end

  def button_down(id)
    close if id == Gosu::KbEscape
  end

  def play_song
    Gosu::Song.new(self, 'media/bouncing.mp3').play unless Gosu::Song.current_song
  end
end


class Player
  attr_accessor :score, :speed
  attr_reader :x, :y

  def initialize(window)
    @image = Gosu::Image::load_tiles(window, "media/unicorn_anim.png", 97, 101, false)
    @plopp = Gosu::Sample.new(window, "media/plopp.wav")
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @score = 0
    normal_speed
    place_at(600, 450)
  end

  def collect_ballons(ballons)
    !!ballons.reject! do |ballon|
      Gosu::distance(@x, @y, ballon.x, ballon.y) < 60 and kill(ballon)
    end
  end

  def kill(ballon)
    self.score += ballon.points
    @plopp.play
  end

  def place_at(x, y)
    @x, @y = x, y
  end

  def turn_left
    @angle -= 4.5
  end

  def turn_right
    @angle += 4.5
  end

  def accelerate
    @vel_x += Gosu::offset_x(@angle, 0.5)
    @vel_y += Gosu::offset_y(@angle, 0.5)
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x %= 1200
    @y %= 900

    @vel_x *= speed
    @vel_y *= speed
  end

  def normal_speed
    self.speed = 0.95
  end

  def slow_down
    self.speed = 0.45
  end

  def draw
    img = @image[Gosu::milliseconds / 100 % @image.size];
    img.draw_rot(@x, @y, 1, @angle)
  end
end

class Cloud
  attr_reader :x, :y, :window, :direction

  def initialize(window, direction)
    @window = window
    @x = 0
    @y = rand(800) + 50
    @direction = direction
    @speed = rand(5)+3
  end

  def move
    if direction == :right
      @x += @speed
      @x %= 1200 if @x > 1200
    else
      @x -= @speed
      @x %= 1200 if @x < 0
    end
  end

  def intersect?(player)
    Gosu::distance(@x, @y, player.x, player.y) < 90
  end

  def draw
    img = Gosu::Image.new(window, "media/cloud.png", true)
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0, Zindex::Clouds, 1, 1)
  end
end

class Ballon
  attr_reader :x, :y, :window, :animation, :type

  def initialize(window)
    @window = window
    @x = rand * 1200
    @y = rand * 900
    @type = random_type
    @animation = animation_from_type
  end

  def points
    { green: 5, magenta: 1 }[type]
  end

  def draw
    img = animation[Gosu::milliseconds / 100 % animation.size];
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0, Zindex::Ballons, 1, 1)
  end

  private

  def animation_from_type
    Gosu::Image::load_tiles(window, "media/ballons_#{type}.png", 50, 60, false)
  end

  def random_type
    @room ||= [:magenta, :magenta, :magenta, :magenta, :green]
    @room.sample
  end
end


window = GameWindow.new
window.show
