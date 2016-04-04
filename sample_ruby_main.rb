#!/usr/bin/ruby
load 'sonic-processing.rb'

the_code = <<EOC
def setup
  size 200, 200
  background 0
  no_stroke
  smooth
  @rotation = 0
end

def draw
  #background 200
  fill 0, 20
  rect 0, 0, width, height

  translate width/2, height/2
  rotate @rotation

  fill 255
  ellipse 0, -60, 20, 20

  @rotation += 0.1
end
EOC

the_2nd_code = <<EOC
def setup
  size 200, 200
  background 0
  no_stroke
  smooth
  @rotation = 0
end

def draw
  background 200
  fill 0, 20
  rect 0, 0, width, height

  translate width/2, height/2
  rotate @rotation

  fill 255
  ellipse 0, -60, 20, 20

  @rotation += 0.1
end
EOC

Thread.new do
  start_sketch the_code
end
puts '*** sleep while jirb is starting...'
sleep 10
update_sketch the_2nd_code
$irb_stdin.close
sleep 1
