# Welcome to Sonic Pi v2.10

load "~/github/sonic-processing/sonic-processing.rb"
set_use_pty true
#set_use_pty false

#rp5_inline_sketch({:full_screen => true})
rp5_inline_sketch

# Ported from http://nodebox.net/code/index.php/Graphics_State

# This sketch demonstrates how to use the frame rate as orbital state,
# as well as how to use system fonts in Ruby-Processing.
attr_reader :d_font

def setup
  size 450, 450
  frame_rate 30
  smooth
  fill 0
  @d_font = create_font('Helvetica', 40)
end

def draw
  background 255
  translate 225, 225
  text_font d_font
  ellipse 0, 0, 10, 10
  text 'sun', 10, 0
  3.times do |i|
    push_matrix
    rotate frame_count / -180.0 * PI + i * PI / -1.5
    line 0, 0, 120, 0
    translate 120, 0
    ellipse 0, 0, 10, 10
    text_font d_font, 22
    text 'planet', 10, 0
    rotate frame_count / -30.0 * PI
    line 0, 0, 30, 0
    text_font d_font, 15
    text 'moon', 32, 0
    pop_matrix
  end
end
