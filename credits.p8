pico-8 cartridge // http://www.pico-8.com
version 27
__lua__

-- debug = true
-- debug2 = true

scrolldown_i = 30
scrolldown_i_factor = 0.5
current_art_i = 0
art_switchout_i = 0
art_switchin_i = 0
frame_count = 0
credits_done = false

cast_commanders = {
  {198, 8, "hachi", "tea", "medicine", "commander-in-chief",
    "hachi retired from\nhis post and opened\na war supplies shop."
  },
  {238, 8, "sami", "chocolate", "cowards", "infantry specialist",
    "sami was promoted\nand is training a new\nteam of mechanics and a\ndirect combat\nspecialist."
  },
  {236, 12, "bill", "casinos", "cats", "risky strategist",
    "bill escaped jethro\nand bought a pit bull.\nhe finally feels safe."
  },
  {206, 12, "alecia", "smoothies", "fast food", "chief medic",
    "alecia returned home\nand rebuilt her town."
  },
  {200, 12, "conrad", "cats", "callous friends", "munitions expert",
    "conrad adopted jethro\nand fell in love with\nalecia.\nthey rebuilt her town\ntogether."
  },
  {234, 11, "guster", "computers", "love", "techno-marksman",
    "guster built a robot\nwife, whom he is very\ndissatisfied with."
  },
  {230, 14, "slydy-hachi", "???", "???", "???",
    "slydy-hachi turned\nback into slydy\nand ceased to exist."
  },
  {202, 14, "glitch", "profanity", "patterns", "computer error",
    "glitch moved into\nguster's server\nnetwork, and then moved\ninto his robo-wife.\nguster has no idea."
  },
  {232, 14, "slydy", "herself", "hachi", "gooey glitch-queen",
    "slydy melted into\nnothingness."
  },
  {228, 14, "storm", "friendship", "abandonment", "genius teen",
    "storm lost his only\nfriends, who he created\nout of deep loneliness.\nhis heart imploded,\ncreating a black\nhole."
  },
  {196, 11, "jethro", "sea-meat", "chipmunks", "warlord",
    "jethro moved in with\nconrad and alecia.\nhe wishes they fed him\nwet food twice a day."
  },
}

cast_units = {
  {192, "infantry"},
  {193, "mech"},
  {194, "recon"},
  {195, "tank"},
  {208, "war tank"},
  {209, "artillery"},
  {210, "rockets"},
  {211, "apc"},
}

cast_humans = {
  "special thanks to",
  "cattywhompus",
  "bhor",
  "and caaz",
  "",
  "thanks to nintendo",
  "for making advance wars",
  "",
  "and my mom for buying",
  "me the game in 2002.",
  "",
  "",
  "",
  "thank you very much",
  "for playing ♥"
}

cast_art = {
  0,
  128,
  72,
  8,
  64,
  0,
}

function _init()
  if debug then 
    scrolldown_i = -250
  end
end

function _update()
  frame_count += 1
  update_cast()

  if scrolldown_i == 20 then
    music(6)
  end

  if (btnp(4) or btnp(5)) and credits_done then
    load("loader.p8")
  end

end

function _draw()
  cls()
  draw_cast()
end

function update_cast()
  if not credits_done then
    scrolldown_i -= scrolldown_i_factor
    if debug2 then
      scrolldown_i -= 10
    end
  end
end

function draw_cast()
  local y_val = 128
  local x_centered = 80
  local x_left = 42

  print_double("= cast =", x_centered, y_val + scrolldown_i, 7, 8)
  y_val += 64

  -- draw terrain below units
  for i=0, 74 do
    local field_sp1 = 159
    local field_sp2 = 159
    local road_sp = 143
    if i % 10 == 0 then field_sp1 = 175 end
    if i % 7 == 2 then field_sp2 = 175 end
    if i == 29 then
      field_sp1, field_sp2, road_sp = 191, 191, 142
    end
    -- draw road
    spr(road_sp, x_left, i*8 + y_val + scrolldown_i*2)
    -- draw fields on left/right
    spr(field_sp1, x_left - 8, i*8 + y_val + scrolldown_i*2)
    spr(field_sp2, x_left + 8, i*8 + y_val + scrolldown_i*2)
  end

  -- draw units
  for i=0, #cast_units-1 do
    local u = cast_units[i+1]
    local sprite_offset = 0
    if frame_count / 10 % 2 > 1 then sprite_offset = 32 end
    spr(u[1] + sprite_offset, x_left, y_val + scrolldown_i)
    print_double(u[2], x_centered, y_val + scrolldown_i + 1, 7, 8)
    y_val += 26
  end

  y_val += 72

  print_double("= commanders =", x_centered, y_val + scrolldown_i, 7, 8)

  y_val += 64
  for i=0, #cast_commanders-1 do
    local co = cast_commanders[i+1]
    if frame_count / 10 % 2 > 1 then sprite_offset = 32 end
    spr(co[1], x_left - 8, y_val + scrolldown_i, 2, 2)
    -- name
    print_double(co[3], x_left + 10, y_val + scrolldown_i, 7, co[2], false)
    y_val += 9
    -- title
    print_double(co[6], x_left + 10, y_val + scrolldown_i, 7, co[2], false)
    y_val += 9
    -- hit
    print_double("hit: " .. co[4], x_left - 7, y_val + scrolldown_i, 7, co[2], false)
    y_val += 9
    -- miss
    print_double("miss: " .. co[5], x_left - 7, y_val + scrolldown_i, 7, co[2], false)
    y_val += 14
    -- bio
    print_double(co[7], x_left - 7, y_val + scrolldown_i, 7, co[2], false)
    y_val += 9

    y_val += 64
  end

  y_val += 24

  print_double("= special tanks =", x_centered, y_val + scrolldown_i, 7, 8)

  y_val += 64
  for i=0, #cast_humans-1 do
    local line = cast_humans[i+1]
    print_double(line, x_centered, y_val + scrolldown_i, 7, 8)
    y_val += 9
  end

  y_val += 64

  print_double("pico-wars ~ the end", x_centered, y_val + scrolldown_i, 7, 8)

  -- final message
  if y_val + scrolldown_i <= 64 then credits_done = true end

  -- draw art at left
  if not art_y_count then
    art_y_count = y_val
  end

  if y_val + scrolldown_i <= art_y_count then
    local art_divisions = y_val / #cast_art
    art_y_count -= art_divisions
    current_art_i += 1
    art_switchout_i = 20
  end

  draw_art()
end

function draw_art()
  local art_i = current_art_i
  local art_x = 0

  if art_switchin_i > 0 then
    art_switchin_i -= 1
    art_x = -((art_switchin_i) / 2)^2
  end

  if art_switchout_i > 0 then
    art_i -= 1
    art_switchout_i -= 1
    if art_switchout_i == 0 then
      art_switchin_i = 20
    end
    art_x = -((20 - art_switchout_i) / 2)^2
  end

  local art = cast_art[art_i]
  if art then
    spr(art, art_x, 32, 4, 4)
    spr(art + 4, art_x, 64, 4, 4)
  end
end

function print_double(str, x, y, col, double_color, centered)
  if centered == nil then centered = true end

  for a=x-1,x+1 do
    for b=y-1,y+1 do
      if centered then
        print_centered(str,a,b,double_color)
      else
        print(str,a,b,double_color)
      end

    end
  end
  if centered then
    print_centered(str, x, y, col)
  else
    print(str, x, y, col)
  end
end

function print_centered(str, x, y, col)
  print(str, x - #str*2, y, col)
end

__gfx__
550000000000000000000000000000000000000000000000fffffff8f00fff00cccccccccccccccccccccccccccccccc13333333311dddd4dddddddddddddddd
55500000000000888800000000000000000000000000000133777287830fff00ccccbbccccccccccccccccccccccccccd11111111ddddd4ddddddddddddddddd
5555550000000008888888800000000000000000000000133333387111ffff00cccbbbbcccccccccccccccccccccccccdd111111dddd42dddddddddddddddddd
0555550000000888888888800000000000000000000000131333312188fff000ccbbbbbbccccccccccccccccccccccccdd22222dddd2dddd22dddddddddddddd
0555555000008288888888888000000000000000000000133113331282fff000cbbbbbbbbccccccccccccccccccccccced42422ed4222222dededededededede
0055655000022288877888888800000000000000000001333111133111ff0000bbbbbbbbbbccccccccccccccccccccccde4442222222edededededededededed
0055655500022887788811188800000000000000000001333310013333110000bbbbbbbbbbbccccccccccccccccc7ccced424222bededededededededededede
0005565500288878811133118880000000000000000001333330001333300000bbbbbbbbbb3cccccccccccc77c77777cee42422b3eeeeeeeeeeeeeeeeeeeeeee
000556555222228813333331111000000000000000000133330000133330000033bbbbbb33ccccccccccc77777777777ee424b333bbbeeeeeeeeeeeeeeeeeeee
000055555522220fffffff3333100000000000000000013333000013333000003333bb3333ccccc7ccc6666666666666ee42b3333333eeeeeeeeeeeeeeeeeeee
00005556550222222fff222f3380000000000000000001333300001333300000133333333ccccc777c7cccccccccccccee4b733333733eeeeeeeeeeeeeeeeeee
000555565550222702f2702f8880000000000000000011133300001333300000c11333311cc7c77777777cccccccccccee4b3737333333eeeeeeeeeeeeeeeeee
00555555655022f2cfffc2ff88e0000000000000000017113300001331111000c111111116666666666666ccccccccccee4323333f3333eeeeeeeeeeeeeeeeee
00055555655522fffffffff88ff0000000000000000071111100000111711000bbb1111bbbbcccccccccccccccccccccae42f20732072faeaeaeaeaeaeaeaeae
00000055665522fff2efffffff80000000000000000071113000000111171000bbbbbbbbbbbbccccccccccccccccccccea43ff222f22effaeaeaeaeaeaeaeaea
0000ff55565222fffffff2f88880000000000000000011113000000111171000bbbbbbbbbbb33cccccccccccccccccccae424fffffffa55eaeaeaeaeaeaeaeae
000ffff55662222fff222f8888000000000000000000111130000001111110003bbbbbbbbb333cccccccccccccccccccaa4242ff12ffa11aaaaaaaaaaaaaaaaa
000ffff555622222fffff8f88800000000000000000011111000000111111000333bbbbb33331cccccccccccccccccccaa424217f711111aaaaaaaaaaaaaaaaa
00005ff555552222200eeff88000000000000000000001333000000131110000333333333331ccccccccccccccccccccaa424117271111aaaaaaaaaaabb3aaaa
00055555500550220e7ffff77ff000000000000000001333300000013333000011333333311ccccccccccccccccccccc33241111211aaaaaaaaaaaabbbb333aa
0000555f0000550ff77fff777fff000000000000000013333000000133330000bb1133311bbbcccccccccccccccccccc33241111111333333aaaabbbbbbb383a
00005fff00005fff777fff777fff000000000000000013333000000133330000bbbb111bbbbbb3cccccccccccccccccc32241111111333333333bbbbbbbb3533
000000fff000fff677fff7777ffff00000000000000013333000000133330000bbbbbbbbbbbb331ccccccccccccccccc24241151111333333333333bbbbb3533
000000fff77fff6777efe7777fffff00000000000000013330000001333300003bbbbbbbbb3331cccccccccccccccccc224455f6466333333333333333555555
0000000ff77ff6777766777777ffff0000000000000001333000000133330000333bbbbb33331dcdcdcdcdcdcdcdcdcd32442f662663333333333e3e56666565
00000000f77ff67777677777770ffff000000000000001333000000111110000333333333331bbdcdcdcdcdcdcdcdcdc2442266626643333333333a555555556
000000000000067777777777700ffff00000000000000111100000005500000011133333111bbbbdcdcdcdcdcdc1c1cd444226112614433333333e5e66666656
0000000000000067777777767000fff000000000028800550000000055888e00bbb11111bbbbbbb3dddddddddd1d1d1d42223d113d12223333333356e66e6656
0000000000000006677766677000fff0000000002888805500000000818888e0bbbbbbbbbbbbb3331dddddddd1ddddd122333111311333333333335686686656
0000000000000006777777777000fff0000000002888888810000008888888e0bbbbbbbbbbb33331dddd1d1ddddddddd23333111111133333333335662266655
0000000000000000666666666000fff0000000002228222220000002888888803bbbbbbbbb33311dddd1d1d1dddddddd33333333333333333333333555555535
0000000000000000fffffffff000fff000000000111111111000000022222220333bbbbb33311ddddddddddddddddddd33333333333333333333333533333533
00000000011111111111111000000000222222d22ddddddddddd222d2222222299999999999999999999999999999999ee0111111c1000049494555500ffffff
0000000012e777777722227100000000222222dd2ddddddddddd2dd12222222299999999999999999999999999999999ee091111c1c0f00a0a0a05550fffffff
000000000111111111111110000000002222221ddddddddddddddd122222222299999999999999999999999988899999e09440111c10f00a0a0af0050fffffff
0000000000100556655001000000000022212221ddddddddddd7ddd11222222299977799999999999999999888889999e094fff00000050500ffff000fffffff
00000000001056777665010000000000111111111d77ddd7dddddd111111111177777779777999999999998888888999e09427227249900000ffff0ff0ffffff
00000000001005333350010000000000000011ddddddddddddddd1110000000077777777777779999999998888888997e044242242440ffff00000ffff00ffff
00000000001002676620010000000000000001111ddddddddd1dd1101000000066666666666666696999998888888966ee044fffff00fffff012110fffffffff
00000000001082b22b28010000000000000100111dd1ddd1dd11d1111000000099999999999999999999999888879999ee044422f0e0ffff0112110ffffffff0
00000000001012211221010000000000000111111dd1ddd1dd11d1111000000099999999999999999999977988777799e044141110e0fff0111211100fffff0e
000000000010821001280100000000000000111111d1ddd1dd1111110000000099999999999999999997777777777777ee01112110ee0f000000000000ffff0e
000000000010022112200100000000000000001111d111d11d1111110000000099999999999999696666666666666666e0111112110ee0cccccccccccc00f0ee
0000000000100055550001000000000000000111111111d11d111111100000009999999999999999999999999999999901101110110eee011111211111cc0eee
8888888888188a6a565881888888888800000001111111d111111110000000009999999999999999999999999999999911001001000eee011000000011c1ccee
aaaaaaaaaa1a55555555a1aaaaaaaaaa00000000111111111111111100000000999999999999999999999999999999991100112110eeee01110eeeee011cccee
888888888818565115658188888888880000000011111111111111010000000099999999999999999999999999999999011aaaaaa0eeee01110eeeee011c0cce
000000000010565335650100000000000000000011111111111111000000000099999999999999999999999999999999d001121110dddd01110ddddd011c0ccd
00000000001056522565010000000000000000011011f1f111f110000000000099999999999999999999999999999999dd01121110dddd01110ddddd0111cdcd
0000000000105652256501000000000000000000000011ff1f0000000000000099999999999999999990000009999999dd01121110dddd01110ddddd0111cddd
000000000010151221510100000000000000000000000fffff000000000000009999999999999999990ffffff0999999dd01121110dddd01110ddddd01110ddd
000000000010151221510100000000000000000000000fffff00000000000000999999999999999990ffffffff099999dd011211110ddd01110ddddd01110ddd
00000000001015122151010000000000000000000000ff2f2ff000000000000099999999999999990fffffffff099999dd011211110ddd01110ddddd01110ddd
0000000001111111111111100000000000000000000ffff2ffff00000000000099999999999999990222222222099999dd011211110ddd01110ddddd01110ddd
000000001722722227722271000000000000000000fffffffffff00000000000999999999999999902c722c72209999922011211002222011102222201110222
00000000010000000000001000000000000000000ffffff2ffffff00000000009999999999999999021722172f09999922000000402222205552222205550222
0000001111111111111111111100000000000000fffffffffffffff0000000009999999999099990022202222809999922204020402222044440222044440222
000001222222222222222222221000000000000ffffffff2ffffffff0000000099999999905099050fffffff8090099965504400440550222220560222220666
000010000000000000000000000100000000000fffffffffffffffff0000000099999999907500570fff22f8f005099955550055005550000000550000000555
011111111111111111111111111111100000000fffffffffffffffff0000000099999999906555561fffffff0055509922222222222222222222222222222222
12222222222222222222222222222221000000fffffff2fff2fffffff0000000999999999057557550000000f055000966666666666666666666666666666666
22222222222dd2222d22222222222222000000fffffffffffffffffff000000099999999990055055000000005550ff060606606060660666660606660666066
00000000000dddd0ddd0000000000000000000fffff2fffffff2fffff0000000eeeee0000e050055555555555550ffff60606666660666660660606060666060
1111111111ddddddddd1111111111111000000fffffffffffffffffff0000000eee001111000555949495555550fffff00606606060660060660600600606060
bbbbbbbbbbbbbbbbbbbb777777777bbbb7b7b77788888777777ccccc7777b7b70000000000000000000000000000000000000000000000005666665566666663
bbabbbbbbbbbbbbbbbbb777777777bbb7b7b77789999987777c66666c77b7b7b000000000000000000000000000000000000000000000000c66666cc66666663
baaabbbb7bbbbbbbbbbb777777777abbb7b7b7789999998777c666666777b7b70000000000000000000000000000000000000000000000005667665c66676663
bbabbbbbb7bbbbbbbbbbb7777777aaab7b7b7b722222227775555555577b7b7b000000000000000000000000000000000000000000000000c66766cc66676663
bbbbbbbbbb7bbbbbbbbbb7777777aaabb7b7b77ff1ff1f7777f1ff1ff7b7b7b70000000000000000000000000000000000000000000000005666665c66666663
bbbbbbbbb7bbbbbbbbbbbaa77aaaaabb777b7b77fffff577775fffff7b7b7b7b000000000000000000000000000000000000000000000000c66666cc66666663
bbbbbbbbbbbbbbbbb7b7aaaaabbbbb7b7777ffff28555557755555c5ffffb7770000000000000000000000000000000000000000000000006667666666676663
bbbbbbbbbbbb7b7b7b7a7abbbbbbb7b7cccfffff8ff866666666cffcfffffccc0000000000000000000000000000000000000000000000006667666366676663
bbb7b7bbbbbbbbbba7a7b7b7bbbbbb7bcb4ffffffff6666776666ffffffff2bc0000000000000000000000000000000000000000000000000000000033333333
bb7b7b7b7b7bbbbaaaab7b7b7bbbb7bbba44fffffff6666666666fffffff22ab0000000000000000000000000000000000000000000000000000000033333333
b7b7b7bbbbbbbaaaabbbb7b7b7bbbb7bba444ffffff6666776666fffff2222ab0000000000000000000000000000000000000000000000000000000033333333
7b7b7bbbbbbbaab777bbbb7b7b7bbbbbcba44444444444444444444444222abc0000000000000000000000000000000000000000000000000000000033333333
b7b7bbbbb7baabbb7bbbbbb77777bbabbcba44444444444444444444442aabbb0000000000000000000000000000000000000000000000000000000033333333
7b7bbbbb7b7abbbbbbbbbb7777777aaacbcbaaaaaaaaaaaaaaaaaaaaaaabcbcc0000000000000000000000000000000000000000000000000000000033333333
77bbbbb7b7abb7bbbbbbb7b77777b7abcbbb77b7777777777b777b77b7bbbbcb0000000000000000000000000000000000000000000000000000000033333333
777bbbbbaabb7b7bbbbb7b7777777b7bcccbcbbbbbb77777b77777b7bbbbbccc0000000000000000000000000000000000000000000000000000000033333333
7777bbbbabb7b7b7b7b7b7b77777b7bbccccccccbbbbb777b7b7bbcbbbbcbcbc0000000000000000000000000000000000000000000000000000000033b33b33
7777bbb7bbbb7b7b7b7b7b7b7b7b7b7bccbcbbcbbc7bb77b7b7bb7bbcccccccc000000000000000000000000000000000000000000000000000000003bbb5bb3
7777bb7bbbbbb7b7b7b7b7b7b7b7b777cccccbccbbbbbbbbb7cccccccccccccc000000000000000000000000000000000000000000000000000000003bb5bb53
777bb7b7777b7b7b7b7b7b7b7b7b7777ccccccccccbbbbbbbbbccbccbccccccc00000000000000000000000000000000000000000000000000000000bb5b5bb5
77bbbb777777b7b7b7b7b7b7b7b77777ccccccccbbbbbbbbccbcbbbccccccccc000000000000000000000000000000000000000000000000000000003b5bbb53
7bbbb77777777777777b7b7b7b777777cccccbcccbccbbbbbbbbbccccccccccc00000000000000000000000000000000000000000000000000000000bbb5bbb5
b7bbb777777777777777b7b7b7777777cccccccbbbbbbbbbbbbcbbcccbcccbcc0000000000000000000000000000000000000000000000000000000033433433
7b7b777777777877778b7b7b7b777777ccccccccccccbbbcbcbccccccccccccc0000000000000000000000000000000000000000000000000000000033333333
b7b77777777788877888b777b7777777ccccccccccbccbbbcccccccccccccccc0000000000000000000000000000000000000000000000000000000055555555
7b77777777788788888887777b777777ccccccccccbbbbcccccccccccccccccc00000000000000000000000000000000000000000000000000000000cccccccc
b7777777777888888888877777b77777cccccccccccbbccccccccccccccccccc00000000000000000000000000000000000000000000000000000000cccccccc
7b77777777778888888877777b7b7777cccccccccccbcccccccccccccccccccc00000000000000000000000000000000000000000000000000000000cccccccc
b7777777777778888887777777b7b777cccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000cccccccc
7b7777777777778888777777777b7b7bcccccccccccbcccccccccccccccccccc00000000000000000000000000000000000000000000000000000000cccccccc
b7b77777777777788777777777b7b7b7cccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000066666666
7b7b77777777777777777777777b7b7bcccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000033333333
088888000888888700000000000000000000500000050000000002333333333200000222222220000000000ff000000255500000000000050011111111111100
89999980899999870088800000888800000575000057500000002333333333330002277ffffff200000000faafff22025570000000000070011c111111111111
89999998899999980878780008788780000565555566d500000233333333333300277fffffffff2000fffffaaaaaf222500707077700700011c1c11111111111
22222220222222260918190008199180000566666666d5000006333333333333027ffffffffffff200ffaaaaa0aaa2220000000000000000111c111111111444
ff1ff1f08f1f17770995990029555592005676666676d500002666fff333366302222fff2222fff200faaaaa080aaa22000fffffffff00001111111111449494
0fffff7008fff7572895982082555528005606666606d500002f666ffff66663029492f294942ff20faaaaaa000aaa220022ffffff22f0001111111fffff4949
02877777028886668299928028299282005665656566d50002fff66fff66663302222fff22224ff20faa000aaaa4aa2202662f22f2662f08411112fff222f442
08000000020000002820282082899828005666565694949002f00fffff66ff630226cfff2c66f2f20faa080aaaa4aa220274688f267428804426742f26742442
02222220002120002220022200000000000556666649494002fff0f2f00ffff6022712ff2172fff200f20004444aaa2208898f2828898ff04f2649fff6492422
298998920022200021200212009999000555556655a5a5a02fffff2ffff0fff602f22f2ff22ffff202f22a44aaaaaaf28f282f2f8228fff04ff222fff222f422
297887920022200022299222097997905666666566ada5a02fffff2fffffffff02ffff2ffffff8f20022aaaaaaaffff28ff8ff2f8ff8ffff4ffffffffffff424
2918819202787200227887220919919056d555656da5a5a02fffffffffffffff02ffff2fffff8f202022aaaaaff22002588fff22f88fffff4ffffff2fffff424
2955559208181800091881902999999205500567557dd50002fff22222f2fff302fffffffff8f2000222faaaff2222025ffffffffffffff54ffffffffffff424
8251152822222220829999288291192800000567777dd500002fffffffffff6302fff220ff8f2200022220000002222255ffffffffffff5540ffffffff2ff400
2855558282999280289889822829928200000567777dd50000022ffffffff32300ffffffffff2200220222222222222255ffff222ffff255400fff2222fff400
8289982828202820820000288289982800000567777dd500000002222222230300222222222222000000000000022222555fffffffff225540000ffffff00400
08888800088888870000000000000000000dddddddd0d0d0000002333333333200eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
899999808999998700888000008888000ddddddddddddd0000002333333333330eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
89999998899999980878780008788780dd7ddddddddd7ddd0002333333333333ee77eeeeeee222ee073333333333373001111111111111112888888888828878
222222202222222609181900081991800dd77ddd7dddddd00006333333333333e77e22f2eeefff2e337333333333333011111155555555518788881118882788
ff1ff1f08f1f17770995990089555598ddddd1d1d1dd1d1d002666fff3333663e7eefff2eeeffffe3333733333733333111555ccccccccc58878113331888288
0fffff7008fff7578295928028555582ddd1d111111d11d1002f066fff066663eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c8881333333188828
02877777028886662899982082899828ddd111f11f11f11d02ff006fff666633e7ef00ff2ee000feb3f2222fbb322f2015ccf222ffff222f8813222ffff28882
00008000000020008280828028299282dd110000ff00001102f000fff000ff63ee2f070f2ef070fef2ff2222ffb222205c2f27772ff2777282226722ff262888
02222220002120002220022200000000ff1f222ffff22f1102f070f2f070fff6ee2f070f2ef000feff2226422222462012f267172ff271728227707fff707288
29899892002220002120021200999900ff1f27d2ff2d72102ff0002ff000f2f6ee2f000fffff0f2effff27a2fff2a7202fff26772ff267722ff20c7fff0c6228
29788792002220002229922209799790ffff2717ff2172002ff00f2ff000f2ffee2ff0ffffff0f2e2fff2222fff2222012fff212ffff222fffff222fff222ff8
2918819202787200227887220919919011fff222fff22f002fff0fffff0ff2ff0e2fff222222f2e02ffffffff22fff20002fffffffff2ff02ffffffff2fffff2
29555592081818000918819089999998011ffffff22fff0002ffffffff0ffff30ee2ffeeeeeff2e002ff2fffffffff200002ffffff22fff022ffffffffffff22
285115828222228028999982289119820002fffffffff200002ffff22222ff6300ee20ffffff002e002ffff2222fff2000002fffffffff00002ffffffffff222
8255552828999820829889288289982800002fff222ff00000022ffeeeeff323000e2000099fffa000222ffffffff200000222ff1222f0000002fff222ff2222
28299282828082802800008228299282000002ffffff2000000002222222230300002aafffffffaf02222222222220000022222ffffff200000002ffff202020
__sfx__
00100000035500050007550055500a500055500355000500005500a500035500a500005500a500035500f500075500050007550055500a500055500755000500055500a500075500a500055500a500035500f500
001000000355000500035500a5500a500075500355000500055500a500075500a5000a5500a500075500f5000755000500075500a5500a5000a55007550005000c5500a500075500a500055500a500035500f500
001000000350000500035000c5000a500075000750000500035000a500005000a5000a5000a500055000f50007500005000f5000a500115000c5000a500005000f5000a5000c50003500165000a500185000f500
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001862518625000001862518625000001862518600
001000000c5330c500186150f2150c5330f21518615000000c5330f2000c533032000c5330f20018615000000c5330c50018615272150c5332721524615000000c533272000c5331b2000c53333200186150f200
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000017300100186151861500173001001861500100001730010018615186150017300100186150010000173001001861518615001730010018615001000017300100186151861500173001000010000100
0010000013400134001340013400134001340013400134001b4001b4001b4001b4001b4001b4001b4001b4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f400
001000001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001b4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f4001f400
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002772027710277102b7202b7102b7102972029710297102971029720297102e7202e71030720307102e7202e7102e710297202971029710297102971029710297102e7202e71033720337103072030710
0110000035720357103571027720277102771027710277102472024710247102b7202b7102b7102b7102b7103a7203a7103a7102e7202e7102e7102b7202b7103572035710357102772027710277102472024710
011000002772027710277102b7202b7102b710307203071030710307102b7202b710307203071033720337103772037710377102e7202e7102e7102e7102e7102e7102e7102e7202e71033720337103572035710
011000003a7203a7103a71035720357103571035710357103072030710307102e7202e7102e7102e7102e71030720307103071035720357103571037720377103372033710337103072030710307103373033720
011000003371033710337103371033710337103371033710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002411027110291101b1102411027110291101b1102411027110291101b11030110181103511013110291102b1102e1101d110291102b1102e1101d110291102b1102e1101d1103311022110301102b110
0110000024110271102911016110241102711029110161102411027110291101611033110181103a1100f110291102b1102e11016110291102b1102e11016110291102b1102e110161103a1101b110351102e110
0110000024110271102911016110241102711029110161102411027110291101611033110181103a1100f110291102b1102e11016110291102b1102e11016110291102b1102e110161103a1101b1103f1103f110
011000003f1103f1103f1103f11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001d1201d1101f1101b1201b11016110181201811016110181101b120181101b1201b1101d1201d1101b1201d1101b110181201811018110181101811018110181101b1201b1101d1201d1101f1201f110
011000001d1201f1102211018120181101811018110181101f12022110241101b1201b1101b1101b1101b1101f12022110241101b1201b1101b1101d1201d11022120241101d1101f1201f1101f1101f1101f110
011000001d1201d1101f1101b1201b110161101d1201d1101d1101d1101b1201b1101f1201f1101d1201d11024120221101f1101d1201d1101b1101b1101d1101d1101d1101b1201b1101d1201d1101f1201f110
011000002712024110221101f1201f1101f1101f1101f1101d110181101b120181101b1201b1101d1201d11024120271102911022120221102211022120221102212027110291102712027110271102711027110
011000002711027110271102711027100271002710027100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001b1201b110221201f1201b1201b110221201f120221202412027120291202212022110221201d1201f1202212024120221201f1201f11024120221201f1201f110271202e12027120221201d1201d110
__music__
00 40464048
00 41465148
00 40465048
00 41465148
00 40465248
00 41465348
00 00065008
00 01065108
00 00061d08
00 01061e08
00 00061f08
00 01062008
00 00062108
00 01066208
00 00061008
00 01061108
00 00061208
00 01061308
00 00061408
00 01066008
00 001d1008
00 011e1108
00 001f1208
00 01201308
00 00211408
00 01065108
00 00061608
00 01061708
00 00061608
00 01061708
00 00061608
00 01061808
00 00061908
00 01065808
00 00065908
00 01065908
00 40065948
00 40065948
