pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- pico wars
-- by lambdanaut
-- https://lambdanaut.itch.io/
-- https://twitter.com/lambdanaut
-- thanks to nintendo for making advance wars
-- special thanks to caaz for making the original picowars that gave me so much inspiration along the way

version = "1.0"

dead_str = 'dead'

-- mobility ids
mobility_infantry = 0
mobility_mech = 1
mobility_tires = 2
mobility_treads = 3

unit_infantry = "infantry"
unit_mech = "mech"
unit_recon = "recon"
unit_apc = "apc"
unit_artillery = "artillery"
unit_tank = "tank"
unit_rocket = "rocket"
unit_war_tank = "war tank"

unit_index_infantry = 1
unit_index_mech = 2
unit_index_recon = 3
unit_index_apc = 4
unit_index_artillery = 5
unit_index_tank = 6
unit_index_rocket = 7
unit_index_war_tank = 8


-- sfx
sfx_option_change = 0
sfx_splash_screen_start = 1
sfx_dialogue_char = 2

sfx_infantry_moveout = 14
sfx_tank_moveout = 15
sfx_recon_moveout = 16
sfx_war_tank_moveout = 17
sfx_infantry_combat = 22
sfx_mech_combat = 23
sfx_recon_combat = 24
sfx_tank_combat = 25
sfx_war_tank_combat = 26
sfx_artillery_combat = 27
sfx_rocket_combat = 28

-- portraits
p_sami = 238
p_alecia = 206
p_bill = 236
p_snake = 204
p_guster = 234
p_glitch = 202
p_slydy = 232
p_conrad = 200
p_dan = 230
p_hachi = 198
p_storm = 228
p_jethro = 194


-- music
team_index_to_music = {
  31, 0, 0, 0
}

-- team icons
team_index_to_team_icon = {
  192, 208, 193, 209
}

-- ai unit ratios
-- must add up to 100
ai_unit_ratio_infantry = 25
ai_unit_ratio_mech = 12
ai_unit_ratio_recon = 15
ai_unit_ratio_apc = 0
ai_unit_ratio_artillery = 13
ai_unit_ratio_tank = 12
ai_unit_ratio_rocket = 11
ai_unit_ratio_war_tank = 12

-- byte constants
starting_memory = 0x4300

-- menu index
-- 1=splash screen
-- 2=vs selection
-- 3=campaign dialogue
-- 4=victory/defeat screen
menu_index = 1

main_menu_selected = 0
main_menu_options = {"campaign mode", "verses mode", "unlockables"}

-- verses menu
vs_mode_option_selected = 0
map_index_selected = 0
ai_index_selected = 0
map_index_options = {"eezee island", "arbor island", "lil highland", "long island"}
ai_index_options = {"vs ai", "vs human", "ai vs ai"}

-- fadeout variables
fading = 0

-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame
memory_i = starting_memory
campaign_level_index = 1
dialogue_timer = 0


function _init()
  music(music_splash_screen, 0, music_bitmask)

  -- setup cartdata
  cartdata("picowars") 

  -- setup initial commander data
  make_commanders()

  -- load save
  write_save()
  read_save()

  -- read match result
  read_match_result()

  -- read match metadata
  read_match_meta()
  clear_match_meta()  -- reset match meta memory bits

  match_meta_coming_from_match = true

  if match_meta_coming_from_match then
    menu_index = 4  -- victory/defeat screen
  end

end

function _update()
  local t = time()
  delta_time = t - last_checked_time
  last_checked_time = t
  dialogue_timer += delta_time

  btnp_left = btnp(0)
  btnp_right = btnp(1)
  btnp_up = btnp(2)
  btnp_down = btnp(3)

  btnp4 = btnp(4)
  btnp5 = btnp(5)

  if fading ~= 0 then
    fadeout()
  elseif menu_index == 1 then
    update_main_menu()
  elseif menu_index == 2 then
    update_verses_menu()
  elseif menu_index == 3 then
    update_campaign()
  elseif menu_index == 4 then
    update_victory_defeat_menu()
  end

end

function _draw()
  if menu_index == 1 or menu_index == 2 then
      -- splash screen
      cls()

      rectfill(0, 0, 16, 128, 9) --left and right bars
      rectfill(112, 0, 128, 128, 9)

      spr(32, 33, 19, 8, 2) --logo
      print("version " .. version, 44, 30, 9)

      local sprite_orange_star = 192
      local sprite_green_earth = 193
      local sprite_pink_quasar = 209

      if campaign_level_index < 2 then sprite_orange_star = 224 end
      if campaign_level_index < 2 then sprite_green_earth = 224 end
      if campaign_level_index < 2 then sprite_pink_quasar = 224 end

      spr(208, 47, 38)
      spr(sprite_orange_star, 56, 38)
      spr(sprite_green_earth, 65, 38)
      spr(sprite_pink_quasar, 74, 38)

    if menu_index == 1 then
      draw_main_menu()

    elseif menu_index == 2 then
      draw_verses_menu()
    end
  elseif menu_index == 3 then
    draw_campaign()
  elseif menu_index == 4 then
    draw_victory_defeat_menu()
  end
end

function update_main_menu()
  -- main menu / splash screen

  if btnp_left then 
    main_menu_selected -= 1 
    sfx(0)
  elseif btnp_right then 
    main_menu_selected += 1
    sfx(0)
  end
  main_menu_selected = main_menu_selected % #main_menu_options

  if btnp4 then
    sfx(sfx_splash_screen_start)
    if main_menu_selected == 0 then
      -- start campaign
      init_campaign()
      menu_index = 3
    elseif main_menu_selected == 1 then
      -- open vs mode menu
      menu_index = 2
    end
  end
end

function update_verses_menu()
  if vs_mode_option_selected == 0 then 
    if btnp_left then 
      map_index_selected -= 1 
      sfx(0)
    elseif btnp_right then 
      map_index_selected += 1
      sfx(0)
    end
  elseif btnp_left then 
    ai_index_selected -= 1 
    sfx(0)
  elseif btnp_right then
    ai_index_selected += 1 
    sfx(0)
  end

  if btnp_down or btnp_up then
    vs_mode_option_selected += 1
    sfx(0)
  end

  if btnp4 then 
    -- start vs match
    sfx(1)
    fadeout()
    local players_human = {true}
    current_map = vs_map_index_mapping[map_index_selected+1]
    players_human[1] = ai_index_selected < 2
    players_human[2] = ai_index_selected == 1

    write_assets(current_map, {make_alecia(), make_alecia()}, players_human)
  elseif btnp5 then
    -- back to main menu
    sfx(1)
    menu_index = 1
  end

  map_index_selected = map_index_selected % 6
  ai_index_selected = ai_index_selected % 3
  vs_mode_option_selected = vs_mode_option_selected % 2
end

function init_campaign()
  if campaign_level_index < 1 then campaign_level_index = 1 end
  current_level = campaign_levels[campaign_level_index]
end

function update_campaign()
end

function update_victory_defeat_menu()
  if btnp4 then 
    sfx(1)

    if match_meta_level_index > 0 and match_result_reason == 1 then
      -- campaign level victory. increment campaign counter, save game, and continue to next mission.
      campaign_level_index += 1
      init_campaign()
      write_save()
      menu_index = 3
    else
      -- not campaign mission. return to main menu
      menu_index = 1
    end
  end
end

function draw_main_menu()
  for x = 0, 1 do
    spr(last_checked_time*2 % 2, 24 + x*73, 54, 1, 2, x==1)
  end

  print_outlined(main_menu_options[main_menu_selected+1], 39, 59, 7, 4)

  pal(7,  7 - flr(last_checked_time*2 % 2) * 2)
  print("press    to play", 33, 108, 7)
  spr(240, 57, 106)
  pal()
end

function draw_verses_menu()
  for y = 0, 1 do
    for x = 0, 1 do
      spr(last_checked_time*2 % 2, 24 + x*70, 54 + y*20, 1, 2, x==1)
    end
  end
  rectfill(38, 58 + (vs_mode_option_selected) * 19, 86, 64 + (vs_mode_option_selected) * 19, 4)
  print(map_index_options[map_index_selected+1], 39, 59, 7)
  print(ai_index_options[ai_index_selected+1], 53 + ai_index_selected*-6, 78, 7)
end

function draw_campaign()
  -- draw map
  cls(12)
  map(0, 31, current_level.map_pos[1], current_level.map_pos[2], 16, 16)

  if not active_dialogue_coroutine then
    active_dialogue_coroutine = cocreate(dialogue_coroutine)

  elseif costatus(active_dialogue_coroutine) == dead_str then
    -- dialogue over. run campaign mission

    -- write the map, commander and unit data to memory
    write_assets(current_level.map, {current_level.co_p1, current_level.co_p2}, {true, false})

    fadeout()

  elseif active_dialogue_coroutine then
    coresume(active_dialogue_coroutine)
  end

end

function draw_victory_defeat_menu()
  cls(7)


  if match_meta_level_index == 0 then
    -- campaign level victory. 
    if match_result_reason == 0 then
      local speed = calculate_speed(match_result_turn_count, 1)
      local technique = calculate_technique(match_result_units_built[1], match_result_units_lost[1])
      local score = (speed + technique) / 2
      print_outlined("!!!victory!!!", 38, 8, 3, 11) 
      print_outlined("speed:" .. to_rank(speed), 38, 16, 3, 11) 
      print_outlined("technique:" .. to_rank(technique), 38, 24, 3, 11) 
      print_outlined("total rank:" .. to_rank(score), 38, 32, 3, 11) 
    else
      print_outlined("defeat", 53, 60, 9, 8)
    end
  else
    -- not campaign mission. 
  end

end

function start_map()
  -- start a map
  load("picowars.p8")
end

-- coroutines
function dialogue_coroutine()
  local last_co
  current_dialogue_index = 0

  while current_dialogue_index < #current_level.dialogue + 1 do

    current_dialogue_index += 1
    local next_dialogue = current_level.dialogue[current_dialogue_index]

    if last_co and last_co ~= next_dialogue[1].name then
      -- play commander switchout animation
      for i = 1, 10 do
        draw_dialogue("", 0, -(i / 2)^2)
        yield()
      end
    end
    current_dialogue = next_dialogue

    if not last_co or last_co ~= next_dialogue[1].name then
      for i = 10, 1, -1 do
        draw_dialogue("", 0, -(i / 2)^2)
        yield()
      end
    end

    dialogue_str_i = 0
    while dialogue_str_i < #current_dialogue[2] do
      dialogue_str_i += 1

      local next_char = sub(current_dialogue[2], dialogue_str_i, dialogue_str_i)
      if next_char ~= " " then
        sfx(sfx_dialogue_char)
      end

      dialogue_timer = 0
      if next_char == "." or next_char == "!" or next_char == "?" then
        dialogue_timer = -0.35
      elseif next_char == "," then
        dialogue_timer = -0.15
      end

      while dialogue_timer < 0.0333 do
        draw_dialogue(current_dialogue[2], dialogue_str_i)

        if btnp4 and dialogue_str_i > 1 then
          dialogue_str_i = #current_dialogue[2]
          yield()
          break
        end

        yield()

      end

    end

    while not btnp4 do
      draw_dialogue(current_dialogue[2])
      print("🅾️", 120, 122, 0)
      yield()
    end

    last_co = current_dialogue[1].name

  end
end

function draw_dialogue(string, length, co_x_offset)
  if not co_x_offset then co_x_offset = 0 end
  set_palette(current_dialogue[1].team_index)
  rectfill(0, 96, 128, 128, 9)  -- bground
  line(0, 96, 128, 96, 2)  -- bground border
  pal()
  rectfill(1 + co_x_offset, 98, 18 + co_x_offset, 115, 0)  -- portrait border
  local sprite_offset = 0
  if current_dialogue[3] then sprite_offset = -64 end
  spr(current_dialogue[1].sprite + sprite_offset, 2 + co_x_offset, 99, 2, 2)  -- portrait

  local strings = split_str(string, length)
  local str_i = 102
  for str in all(strings) do
    print(str, 22, str_i, 0)
    str_i += 8
  end
end

function split_str(str, length)
  -- splits a string into parts for dialogue

  if not length then length = 32767 end
  local max_on_line = 18
  local current_str = str
  local built_str = ""
  local strings = {}

  local i = 1
  local i_length = 1
  while i <= #current_str and i_length <= length do
    local next_char = sub(current_str, i, i)
    built_str = built_str .. next_char
    if i > max_on_line then
      if next_char == " " then
        add(strings, sub(current_str, 1, i) )
        current_str = sub(current_str, i + 1)
        built_str = ""
        i = 0
      end
    end
    i += 1
    i_length += 1
  end

  add(strings, built_str)

  return strings

end

-- maps
function map_arbor_island()
  local m = {}

  m.name = "arbor island"
  m.r = {0, 0, 14, 21}
  m.bg_color = 12

  -- should we load the map from a source other than the engine?
  -- 0=false, 1=load from this map, 2=load from secondary map source
  m.load_external = 0

  return m
end

function map2()
  local m = {}

  m.name = "map2"
  m.r = {15, 0, 15, 12}
  m.bg_color = 3

  m.load_external = 0

  return m
end

function map3()
  local m = {}

  m.name = "map3"
  m.r = {31, 0, 26, 25}
  m.bg_color = 12

  m.load_external = 0

  return m
end

function map4()
  local m = {}

  m.name = "map4"
  m.r = {15, 14, 15, 15}
  m.bg_color = 3

  m.load_external = 0

  return m
end

function camp_map_1()
  local m = {}

  m.name = "capital offense"
  m.r = {0, 0, 24, 20}
  m.bg_color = 12

  m.load_external = 1

  return m
end


-- mapping of map options to maps in vs mode selection
-- must appear after all make_map statements
vs_map_index_mapping = {map_arbor_island(), map2(), map3(), map4()}


-- unitdata
function make_units()
  local units = {
    make_infantry(),
    make_mech(),
    make_recon(),
    make_apc(),
    make_artillery(),
    make_tank(),
    make_rocket(),
    make_war_tank()
  }
  return units
end

-- infantry
function make_infantry()
  local unit = {}

  unit.index = unit_index_infantry
  unit.type = unit_infantry
  unit.sprite = 16
  unit.mobility_type = mobility_infantry
  unit.travel = 4
  unit.cost = 1
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_infantry
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_infantry_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 5.5
  dc[unit_index_mech] = 4.5
  dc[unit_index_recon] = 1.2
  dc[unit_index_apc] = 1.4
  dc[unit_index_artillery] = 1.5
  dc[unit_index_tank] = 0.5
  dc[unit_index_rocket] = 2.5
  dc[unit_index_war_tank] = 0.1
  unit.damage_chart = dc

  return unit
end

function make_mech()
  local unit = {}

  unit.index = unit_index_mech
  unit.type = unit_mech
  unit.sprite = 17
  unit.mobility_type = mobility_mech
  unit.travel = 3
  unit.cost = 3
  unit.luck_max = 1
  unit.range_min = 0
  unit.range_max = 0
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_mech
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_mech_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 6.5
  dc[unit_index_mech] = 5.5
  dc[unit_index_recon] = 8.5
  dc[unit_index_apc] = 7.5
  dc[unit_index_artillery] = 7
  dc[unit_index_tank] = 5.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 1.5
  unit.damage_chart = dc

  return unit
end

function make_recon()
  local unit = {}

  unit.index = unit_index_recon
  unit.type = unit_recon
  unit.sprite = 18
  unit.mobility_type = mobility_tires
  unit.travel = 9
  unit.cost = 4
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_recon
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_recon_combat
  unit.is_carrier = false

  -- just a bit stronger vs lighter units than advance wars 2 recon because fog of war is removed.
  -- made into a true anti-infantry unit
  -- if we add fog of war, consider nerfing the recon to advance-wars level
  -- https://advancewars.fandom.com/wiki/recon_(advance_wars_2)
  dc = {}
  dc[unit_index_infantry] = 7.6
  dc[unit_index_mech] = 6.8
  dc[unit_index_recon] = 3.8
  dc[unit_index_apc] = 4.5
  dc[unit_index_artillery] = 4.5
  dc[unit_index_tank] = 0.6
  dc[unit_index_rocket] = 5.5
  dc[unit_index_war_tank] = 0.1
  unit.damage_chart = dc

  return unit
end

function make_apc()
  local unit = {}

  unit.index = unit_index_apc
  unit.type = unit_apc
  unit.sprite = 23
  unit.mobility_type = mobility_treads
  unit.travel = 10
  unit.cost = 5
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_apc
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = 0  -- no combat
  unit.is_carrier = true

  dc = {}
  dc[unit_index_infantry] = 0
  dc[unit_index_mech] = 0
  dc[unit_index_recon] = 0
  dc[unit_index_apc] = 0
  dc[unit_index_artillery] = 0
  dc[unit_index_tank] = 0
  dc[unit_index_rocket] = 0
  dc[unit_index_war_tank] = 0
  unit.damage_chart = dc

  return unit
end

function make_artillery()
  local unit = {}

  unit.index = unit_index_artillery
  unit.type = unit_artillery
  unit.sprite = 21
  unit.mobility_type = mobility_treads
  unit.travel = 6
  unit.cost = 6
  unit.range_min = 2
  unit.range_max = 3
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_artillery
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_artillery_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 9
  dc[unit_index_mech] = 8.5
  dc[unit_index_recon] = 8
  dc[unit_index_apc] = 7
  dc[unit_index_artillery] = 7.5
  dc[unit_index_tank] = 7
  dc[unit_index_rocket] = 8
  dc[unit_index_war_tank] = 4.5
  unit.damage_chart = dc

  return unit
end

function make_tank()
  local unit = {}

  unit.index = unit_index_tank
  unit.type = unit_tank
  unit.sprite = 19
  unit.mobility_type = mobility_treads
  unit.travel = 7
  unit.cost = 7
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_tank
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_tank_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 3.5
  dc[unit_index_mech] = 3.0
  dc[unit_index_recon] = 8.5
  dc[unit_index_apc] = 7.5
  dc[unit_index_artillery] = 7.0
  dc[unit_index_tank] = 5.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 1.5
  unit.damage_chart = dc

  return unit
end

function make_rocket()
  local unit = {}

  unit.index = unit_index_rocket
  unit.type = unit_rocket
  unit.sprite = 22
  unit.mobility_type = mobility_tires
  unit.travel = 6
  unit.cost = 15
  unit.range_min = 3
  unit.range_max = 5
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_rocket
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_rocket_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 9.5
  dc[unit_index_mech] = 9
  dc[unit_index_recon] = 9
  dc[unit_index_apc] = 8
  dc[unit_index_artillery] = 8
  dc[unit_index_tank] = 8.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 5.5
  unit.damage_chart = dc

  return unit
end

function make_war_tank()
  local unit = {}

  unit.index = unit_index_war_tank
  unit.type = unit_war_tank
  unit.sprite = 20
  unit.mobility_type = mobility_treads
  unit.travel = 6
  unit.cost = 16
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_war_tank
  unit.moveout_sfx = sfx_war_tank_moveout
  unit.combat_sfx = sfx_war_tank_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 10.5
  dc[unit_index_mech] = 9.5
  dc[unit_index_recon] = 10.5
  dc[unit_index_apc] = 10.5
  dc[unit_index_artillery] = 10.5
  dc[unit_index_tank] = 8.5
  dc[unit_index_rocket] = 10.5
  dc[unit_index_war_tank] = 5.5
  unit.damage_chart = dc

  return unit
end

-- commanders
function make_commanders()
  commanders = {
    make_dan(),
    make_sami(),
    make_hachi(),
    make_bill(),
    make_guster(),
    make_slydy(),
  }
end

function make_dan()
  local co = {}

  co.name = "dan"
  co.sprite = p_dan
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = true
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- dan's units get 1 more healing from structures
  for unit in all(co.units) do
    unit.struct_heal_bonus = 1
  end

  return co
end
co_dan = make_dan()

function make_sami()
  local co = {}

  co.name = "sami"
  co.sprite = p_sami
  co.team_index = 1  -- orange star
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- sami's infantry, mechs, and apc travels further
  co.units[1].travel += 1
  co.units[2].travel += 1
  co.units[4].travel += 1

  -- sami's infantry and mechs have a +5 to their capture rate
  co.units[1].capture_bonus += 5
  co.units[2].capture_bonus += 5

  -- sami's infantry and mechs have 30% more attack
  for i in all({unit_index_infantry, unit_index_mech}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 1.3
    end
  end

  -- sami's non-infantry units have 10% less attack
  for i=3,#co.units do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 0.9
    end
  end

  return co
end
co_sami = make_sami()

function make_hachi()
  local co = {}

  co.name = "hachi"
  co.sprite = p_hachi
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- hachi's non-infantry and non-mech units cost 15% less
  for i=3, #co.units do
    co.units[i].cost = flr(co.units[i].cost * 0.85)
  end

  return co
end
co_hachi = make_hachi()

function make_bill()
  local co = {}

  co.name = "bill"
  co.sprite = p_bill
  co.team_index = 2  -- blue moon
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- bill's non-infantry units have 10% more luck
  for i=1,#co.units do
    co.units[i].luck_max = 2
  end

  return co
end
co_bill = make_bill()

function make_alecia()
  local co = {}

  co.name = "alecia"
  co.sprite = p_alecia
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  return co
end
co_alecia = make_alecia()

function make_conrad()
  local co = {}

  co.name = "conrad"
  co.sprite = p_conrad
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  for unit in all(co.units) do
    -- conrads's units are only healed by 1 by structures
    unit.struct_heal_bonus = -1

    -- all of conrads units have 10% more firepower
    for i=1, #unit.damage_chart do
      unit.damage_chart[i] *= 1.1
    end
  end

  return co
end
co_conrad = make_conrad()

function make_guster()
  local co = {}

  co.name = "guster"
  co.sprite = p_guster
  co.team_index = 3  -- green earth
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- guster's ranged units have +1 range
  co.units[4].range_max += 1
  co.units[6].range_max += 1

  -- guster's ranged units have 30% more attack
  for i in all({unit_index_artillery, unit_index_rocket}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 1.3
    end
  end

  -- guster's non-ranged, non-infantry units have 10% less attack
  for i in all({unit_index_mech, unit_index_recon, unit_index_tank, unit_index_war_tank}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 0.9
    end
  end

  -- guster's ai prioritizes ranged units
  co.units[unit_index_infantry].ai_unit_ratio = 7
  co.units[unit_index_mech].ai_unit_ratio = 5
  co.units[unit_index_recon].ai_unit_ratio = 5
  co.units[unit_index_apc].ai_unit_ratio = 0
  co.units[unit_index_artillery].ai_unit_ratio = 37
  co.units[unit_index_tank].ai_unit_ratio = 5
  co.units[unit_index_rocket].ai_unit_ratio = 36
  co.units[unit_index_war_tank].ai_unit_ratio = 5

  return co
end
co_guster = make_guster()

function make_slydy()
  local co = {}

  co.name = "slydy"
  co.sprite = p_slydy
  co.team_index = 4  -- pink quasar
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  return co
end
co_slydy = make_slydy()


-- campaign levels
function level_1()
  local l = {}

  l.index = 1
  l.map = camp_map_1()
  l.map_pos = {35, 30}
  l.co_p1 = make_hachi()
  l.co_p2 = make_bill()

  l.dialogue = {
    {co_bill, "ah, orange star's capital. ripe for the pickin!"},
    {co_bill, "..."},
    {co_bill, "but maybe it's too easy.", true},
    {co_bill, "hachi, get your ass out here!"},
    {co_hachi, "oh hey bill! i didn't hear you knock."},
    {co_bill, "cut it hachi. do i look like i'm here for your jokes?"},
    {co_hachi, "always the gracious guest bill! okay, i'm open for business!"},
  }

  return l
end

-- index of all campaign levels 
campaign_levels = {level_1()}

-- memory read/write functions

function write_string(string, length)
  -- writes a string to memory
  for i = 1, length do
    local c = sub(string, i, i)
    local charcode_val = ord(c)
    poke_increment(charcode_val)
  end
end

function peek_increment()
  -- peeks at memory_i and increments the global memory_i counter while doing it
  local v = peek(memory_i)
  memory_i += 1
  return v
end

function poke_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke(memory_i, poke_value)
  memory_i += 1
end

function poke2_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke2(memory_i, poke_value)
  memory_i += 2
end

function poke4_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke4(memory_i, poke_value)
  memory_i += 4
end

function write_unit(u)
  -- writes a unit to memory

  poke_increment(u.index)
  write_string(u.type, 10)
  poke_increment(u.sprite)
  poke_increment(u.mobility_type)
  poke_increment(u.travel)
  poke_increment(u.cost)
  poke_increment(u.range_min)
  poke_increment(u.range_max)
  poke_increment(u.luck_max)
  poke_increment(u.capture_bonus)
  poke2_increment(u.struct_heal_bonus)
  poke_increment(u.ai_unit_ratio)
  poke_increment(u.moveout_sfx)
  poke_increment(u.combat_sfx)
  if u.is_carrier then poke_increment(1) else poke_increment(0) end

  -- damage chart
  for attacked_unit_index, damage_val in pairs(u.damage_chart) do
    poke4_increment(damage_val)
  end

end

function write_co(co, human_player, team_index)
  if not team_index then team_index = co.team_index end
  if human_player then human_player = 1 else human_player = 0 end

  poke_increment(human_player)
  write_string(co.name, 10)
  poke_increment(team_index)
  poke_increment(co.sprite)
  poke_increment(co.team_icon)
  poke_increment(co.music)

  for unit in all(co.units) do
    write_unit(unit)
  end
end

function write_map(m)
  -- write out the map's bounds to memory
  for i=1,4 do
    poke_increment(m.r[i])
  end
  poke_increment(m.bg_color)

  if m.load_external == 0 then
    -- set byte to indicate map shouldn't be loaded from external source
    poke_increment(0)
  elseif m.load_external == 1 then
    -- set byte to indicate map should be loaded from external source
    poke_increment(1)
    -- load the map data into code
  end

end

function write_assets(game_map, game_commanders, team_humans, team_indexes)
  -- write all assets to be loaded by picowars.p8
  -- game_map is a map object created by a make_map function
  -- game_commanders is a 2 indexed table of both of the commanders
  -- team_humans is a 2 indexed table indicating whether the player is a human or ai
  -- team_indexes is an optional 2 indexed table indicating what team each player should be on (orange star, blue moon.. etc)
  memory_i = starting_memory
  if not team_indexes then team_indexes = {} end
  if game_commanders[1].team_index == game_commanders[2].team_index then game_commanders[2].team_index = (game_commanders[2].team_index + 1) % 4 end
  for i=1, 2 do
    write_co(game_commanders[i], team_humans[i], team_indexes[i])
  end
  write_map(game_map)
end

function write_save()
  memory_i = 0x5e00

  -- write campaign score and progress to disk
  poke_increment(campaign_level_index)

  -- write available commanders to disk
  for co in all(commanders) do
    local available = 0
    if co.available then available = 1 end
    poke_increment(available)
  end

  -- write available war maps to disk

end

function read_save()
  memory_i = 0x5e00

  -- read campaign score and progress to disk
  campaign_level_index = peek_increment()

  -- read available commanders to disk
  for co in all(commanders) do
    local available = peek_increment()
    if available == 1 then co.available = true end
  end

  -- read available war maps to disk
end

function read_match_meta()
  memory_i = 0x5ddc

  match_meta_coming_from_match = peek_increment() == 1
  match_meta_level_index = peek_increment()
  match_meta_p1_team_index = peek_increment()
  match_meta_p2_team_index = peek_increment()
end

function write_match_meta(level_index, p1_team_index, p2_team_index)
  -- writes metadata about a match to be read by loader after the match
  memory_i = 0x5ddc

  poke_increment(1)  -- bool to indicate we're entering a match
  poke_increment(level_index)
  poke_increment(p1_team_index)
  poke_increment(p2_team_index)
end

function clear_match_meta()
  -- clears match metadata. run on loader startup
  memory_i = 0x5ddc

  while memory_i < 0x5ddd do
    memory_i += 1
    poke_increment(0)
  end
end

function read_match_result()
  -- reads a match's results from memory and sets global variables for each of them

  memory_i = 0x5ddd -- beginning of match result memory

  -- reasons:
  -- * 1: victory player 1
  -- * 2: victory player 2
  -- * 3: abandon mission
  match_result_reason = peek_increment()
  match_result_units_lost = {}
  match_result_units_built = {}
  for i = 1, 2 do
    match_result_units_lost[i] = peek_increment()
    match_result_units_built[i] = peek_increment()
  end
  match_result_turn_count = peek_increment()
end


function set_palette(palette)
  if palette == 2 then
    pal(9, 6)
    pal(8, 12)
    pal(2, 5)  
  elseif palette == 3 then
    pal(9, 11)
    pal(8, 3)
    pal(2, 10)  
  elseif palette == 4 then
    pal(9, 14)
    pal(8, 2)
    pal(2, 10)
  end
end

function print_outlined(str, x, y, col, outline_col)
  rectfill(x - 1, y - 1, x + #str * 4 - 1, y + 5, outline_col)
  print(str, x, y, col)
end


function fadeout()
  -- by dw817 
  -- https://www.lexaloffle.com/bbs/?tid=36243
  local fade,c,p={[0]=0,17,18,19,20,16,22,6,24,25,9,27,28,29,29,31,0,0,16,17,16,16,5,0,2,4,0,3,1,18,2,4}
  fading+=1
  if fading%5==1 then
    for i=0,15 do
      c=peek(24336+i)
      if (c>=128) c-=112
      p=fade[c]
      if (p>=16) p+=112
      pal(i,p,1)
    end
    if fading==7*5+1 then
      -- start the map when fading is over
      start_map()
    end
  end
end

function calculate_speed(turns_completed, min_perfect_turns)
  return min(100, 100 + min_perfect_turns - turns_completed)
end

function calculate_technique(units_built, units_lost)
  return min(100, 100 * (units_built - units_lost / 2) / units_built)
end

function to_rank(score)
  rank_mapping = {'s','a','b','c','d','f'}
  return rank_mapping[min(6, 11 - ceil(score/10))]
end


__gfx__
0000000700000001000000000000000000000000000000000000000000000000331111330000004400000000220000000000000000f00000566666555ccccc63
000000770000001700000000000000000000000000000000000000000000000033616133000000440000000022000000000000000f4400f0c66666cc5c5c5c66
00000777000001d7000000000000000000000000000000000000000000000000ccc11ccc0000004400000000220000000000000072427f425667665c66666666
0000777d00001dd7000000000000000000000000000000000000000000000000c6c16c6c0000004400000000220000000000000007270722c66766cc66666666
000777dd0001ddd7000000000000000000000000000000000000000000000000ccc11ccc00000044000000002200000000dddd00007f40775666665c66776677
00777ddd001dddd7000000000000000000000000000000000000000000000000c6c16c6c0000004400000000220000000ddddd5007244270c66666cc66666666
0777dddd01ddddd7000000000000000000000000000000000000000000000000ccc11ccc0000044400000000222000000ddddd50007227006667666666666666
777ddddd7dddddd7000000000000000000000000000000000000000000000000ccc11ccc4444444344444444324444440d55555000077000666766635c5c5c66
0111dddd07ddddd700000000000000000000000000000000000000000000000033222233555555530000000035555555006dd500005555000000000033b33b33
00111ddd007dddd700000000000000000000000000000000000000000000000033828233222244450000000052222222065555500d7575d0000000053bbb5bb3
000111dd0007ddd700000000000000000000000000000000000000000000000099922999222222440000000022222222067dd750ddd55ddd005500553bb5bb53
0000111d00007dd70000000000000000000000000000000000000000000000009892898922222244000000002222222206dddd50d7d57d7d055d055dbb5b5bb5
00000111000007d70000000000000000000000000000000000000000000000009992299900000244000000002220000065555555ddd55ddd55dd55dd3b5bbb53
00000011000000770000000000000000000000000000000000000000000000009892898900000044000000002200000067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0000000100000007000000000000000000000000000000000000000000000000999229990000004400000000220000006dddddd5ddd55ddddddddddd33433433
00000000000000000000000000000000000000000000000000000000000000009992299900000044000000042200000067d7d7d5ddd55dddd7d7d7d733333333
000007777770000000000000000000000000000000000000000007777700000033333333000000440000000022000000336666666666666666666333333ff333
00007dddddd700000000000000000000000000000000000000077ddddd7700003333333500000044000000002200000036666666666666666666663333f44233
0007dddddddd700000000000000000000000000000000000007ddddddddd70003355335500000044000000002200000066666666666666666666666333f44233
007dddddddddd7000000000000000000000000000000000007dddd111dddd700355d355d0000004400000000220000006666667766776677667666633f444223
07dddddddddddd777777777777777777777777777777777777ddd10001ddd70055dd55dd0000004400000000220000006666666666666666666766633f442423
071111dddddddd822282228822882288c9c9c999c999cc99cddd1000007ddd10d7d7d7d70000004400000000220000006667666666666666666666633f424423
000000dddddddd828288288288828828c9c9c9c9c9c9c9cccdd100000007dd70dddddddd000000440000000022000000666766666666666666676663b4b4b22b
000000dddddddd822288288288828828c9c9c999c99cc999cdd100000007dd10d7d7d7d70000004440000000220000006666666333333333666766633bbbbbb3
00000ddddddddd828888288288828828c999c9c9c9c9ccc9cdd100000007dd103355553300000044555555552200000066666663333333336666666366666663
00000ddddddddd828882228822882288c999c9c9c9c9c99ccddd1000007ddd103d7575d300000044222222222200000066666666666666666666666366666663
77777ddddddddd11111111111111111111111111111111111dddd70007ddd100ddd55ddd00000042222222222200000066676666666666666667666366676663
1dddddddddddd1000000000000000000000000000000000001dddd777dddd100d7d57d7d00000002222222222000000066676666666666666667666366676663
01dddddddddd100000000000000000000000000000000000001ddddddddd1000ddd55ddd00000000000000000000000066667677667766776676666366666663
001dddddddd100000000000000000000000000000000000000011ddddd110000d7d57d7d00000000000000000000000066666666666666666666666366666663
0001dddddd100000000000000000000000000000000000000000011111000000ddd55ddd00000000000000000000000036666666666666666666663366676663
0000111111000000000000000000000000000000000000000000000000000000ddd55ddd00000000000000000000000033666666666666666666633366676663
00299200002222000000000000000000006cc1000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000
02222220008282000000000200000000061111100061610000000001000000000000000000000000000000000000000000000000000000000000000000000000
02899820999229990022002200222200066cc610ccc11ccc00110011000000000000000000000000000000000000000000000000000000000000000000000000
0299992098928989022902290299992006cccc10c6c16c6c011c011c000000000000000000000000000000000000000000000000000000000000000000000000
2222222299922999229922992999999261111111ccc11ccc11cc11cc000000000000000000000000000000000000000000000000000000000000000000000000
2898989298928989989898980299992066c6c6c1c6c16c6cc6c6c6c6000000000000000000000000000000000000000000000000000000000000000000000000
299999929992299999999999002222006cccccc1ccc11ccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
2898989299922999989898980029920066c6c6c1ccc11cccc6c6c6c6000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000044000000005ccccc65
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00000000000044000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000cc0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000445ccccc6400000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033555555555555555555533333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035ccccccccccccccccccc63333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005cccccc666666666cccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccc63333333335ccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccc63333333335ccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005cccccc555555555cccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006ccccccccccccccccccccc635ccccc63
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036ccccccccccccccccccc6335ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003366666666666666666663335ccccc63
00d0a1a0a0a200000000d000000000000000500000050000000002333333333200000222222220000000000ff000000255500000000000050011111111111100
00000000000000000000000000000000000575000057500000002333333333330002277ffffff200000000f88fff22025570000000000070011c111111111111
00009281f6b200d00000000000d00000000565555566d500000233333333333300277fffffffff2000fffff88888f222500707077700700011c1c11111111111
00000000000000000000000000000000000566666666d5000006333333333333027ffffffffffff200ff8888808882220000000000000000111c111111111444
000092c3d3b2000000a1a0a0a2000000005655565556d500002666fff333366302222fff2222fff200f888880a0888220002fffffff200001111111111449494
00000000000000000000000000000000005666666666d500002f666ffff66663029492f294942ff20f888888000888220022ffffff22f0001111111fffff2949
000093a3a3b300000092f2f6b200000000ee6565656ee50002fff66fff66663302222fff22224ff20f8800088884882202622f22f2262f08411112ffff22f442
0000000000000000000000000000000000ee66565694949002f22fffff66ff6302270fff270ff2f20f880a08888488220274288f22742880442672fff2742442
0000000000a1a0a0a292f6f2b200d000000556666649494002f702f2f22ffff6022072ff2072fff200f200044448882208898f2828898ff04f26492f26492422
000000000000000000000000000000000555556655a5a5a02ff22f2ff072f2f6021c212f1c21fff202f22844888888f28f282f2f8228fff04ff222fff222f422
0000d0000092f181b293a3a3b30000005666666566ada5a02fffff2ff222f2ff02fc1f2ffc1ff8f200228888888ffff28ff8ff2f8ff8ffff4ffffffffffff424
0000000000000000000000000000000056d555656da5a5a02ffffffffffff2ff02fcff2ffcfe8f20202288888ff22002588fff22f88fffff4ffffff2fffff424
00000000d092f6f1b2000000a1a0a0a205500567557dd50002fffffffffffff302f7fffff7e8e2000222f888ff2222025ffffffffffffff54ffffffffffff424
0000000000000000000000000000000000000567777dd500002ffff2222fff6302fcf220fc8f2200022220000002222255ffffffffffff5540fffffffffff400
a1a0a0a0a293a3a3b30000009280f2b200000567777dd50000022ffffffff32300ffffffffff2200220222222222222255ffff222f2ff255400fff2222fff400
0000000000000000000000000000000000000567777dd500000002222222230300222222222222000000000000022222555fffffffff225540000ffffff00400
92f28339b20000000000d00092c3d3b2000dddddddd0d0d0044004444440000000eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
000000000000000000000000000000000ddddddddddddd0004444444444444000eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
d519e0d6c50000000000000093a3a3b3dd7ddddddddd7ddd4444444444444440ee77eeeeeee222ee073333333333373001111111111111112888888888828878
000000000000000000000000000000000dd77ddd7dddddd04944444444444494e77e22f2eeefff2e337333333333333011111155555555518788881118882788
92f1f319b2000000d00000a1a0a0a200ddddd1d1d1dd1d1d4494444444444444e7eefff2eeef00fe3333733333733333111555ccccccccc58878113331888288
00000000000000000000000000000000ddd00111111d10d10444949444494444eeee00022ee0000eb33bfffb333bbbbb115cc1111ccc111c8881233333188828
28a328a3b3d0000000000092f1c6c500ddd000211210001d44444444f4f44442e7e000002e077700b3f2222fbb322f2015cc222222f22222881322fffff28882
00000000000000000000000000000000dd110000220000114042224ff222f424ee2077702e072700f2ff2222ffb222205c2227772ff277728222622fff262888
000000a1a0a0a2a1a0a0a29280f7b20022122200f20022110042784ff7872f42ee2072702e077700ff2226722222762012f267172ff2717282277062f2707288
00000000000000000000000000000000f21f27100f017210000289fff8972f44ee207770fff0000effff2702fff207202fff26772ff267722ff20c7fff0c6228
000000922b82b29283f1b293a3f5b300222f2222ff222200044f22ffff22ff42ee2f000fffff002e2fff2222fff2222012fff212ffff222fffff222fff222ff8
00000000000000000000000000000000112fffffffffff00004fff2fffffff420e2fff222222f2e02ffffffff22fff20002ff2f2ffff2ff02ffffffff2fffff2
00d00092822bb292c383b200000000d00112fffff22fff00044fff22ffffff420ee2ffeeeeeff2e002feeeffffffee200002f2f2ff22fff022ffffffffffff22
000000000000000000000000000000000002fffffffff200000ffffffffff42400ee20ffffff002e002fffff22ffff2000002fffffffff00002ffffffffff222
00000019a3a3b393a3a3b30000d0000000002fff222ff000004fff2222f44240000e2000099fffa000222ffffffff200000222ff7777f0000002ffff22ff2222
00000000000000000000000000000000000002ffffff20000004ffffffff240000002aafffffffaf02222222222220000022222ffffff200000002ffff202020
888888803333333000000000000000000000500000050000000002333333333200000222222220000000000ff000000255500000000000050011111111111100
899999803bbbbb300000000000000000000575000057500000002333333333330002277ffffff200000000faafff22025570000000000070011c111111111111
899899803b333b300000000000000000000565555566d500000233333333333300277fffffffff2000fffffaaaaaf222500707077700700011c1c11111111111
898989803b333b300000000000000000000566666666d5000006333333333333027ffffffffffff200ffaaaaa0aaa2220000000000000000111c111111111444
899899803b343b300000000000000000005676666676d500002666fff333366302222fff2222fff200faaaaa080aaa22000fffffffff00001111111111449494
899999803bb4bb300000000000000000005606666606d500002f666ffff66663029492f294942ff20faaaaaa000aaa220022ffffff22f0001111111fffff4949
88888880333333300000000000000000005665656566d50002fff66fff66663302222fff22224ff20faa000aaaa4aa2202662f22f2662f08411112fff222f442
00000000000000000000000000000000005666565694949002f00fffff66ff630226cfff2c66f2f20faa080aaaa4aa220274688f267428804426742f26742442
11111110222222200000000000000000000556666649494002fff0f2f00ffff6022712ff2172fff200f20004444aaa2208898f2828898ff04f2649fff6492422
1dcdcd102aaeaa2000000000000000000555556655a5a5a02fffff2ffff0fff602f22f2ff22ffff202f22a44aaaaaaf28f282f2f8228fff04ff222fff222f422
1cdddc102aeeea2000000000000000005666666566ada5a02fffff2fffffffff02ffff2ffffff8f20022aaaaaaaffff28ff8ff2f8ff8ffff4ffffffffffff424
1ddddd102eaeae20000000000000000056d555656da5a5a02fffffffffffffff02ffff2fffff8f202022aaaaaff22002588fff22f88fffff4ffffff2fffff424
1cdddc102aaeaa20000000000000000005500567557dd50002fff22222f2fff302fffffffff8f2000222faaaff2222025ffffffffffffff54ffffffffffff424
1dcdcd102aeaea20000000000000000000000567777dd500002fffffffffff6302fff220ff8f2200022220000002222255ffffffffffff5540ffffffff2ff400
1111111022222220000000000000000000000567777dd50000022ffffffff32300ffffffffff2200220222222222222255ffff222ffff255400fff2222fff400
0000000000000000000000000000000000000567777dd500000002222222230300222222222222000000000000022222555fffffffff225540000ffffff00400
11111110000000000000000000000000000dddddddd0d0d0044004444440000000eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
107770100000000000000000000000000ddddddddddddd0004444444444444000eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
17000710000000000000000000000000dd7ddddddddd7ddd4444444444444440ee77eeeeeee222ee073333333333373001111111111111112888888888828878
100770100000000000000000000000000dd77ddd7dddddd04944444444444494e77e22f2eeefff2e337333333333333011111155555555518788881118882788
10070010000000000000000000000000ddddd1d1d1dd1d1d4494444444444444e7eefff2eeeffffe3333733333733333111555ccccccccc58878113331888288
10000010000000000000000000000000ddd1d111111d11d10444949444494444eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c8881333333188828
11171110000000000000000000000000ddd111f11f11f11d44444444f4f44442e7ee00ff2ee000feb3f2222fbb322f2015ccf222ffff222f8813222ffff28882
00000000000000000000000000000000dd110000ff0000114042224ff222f424ee2f070f2ef070fef2ff2222ffb222205c2f27772ff2777282226722ff262888
77777777000000000000000000000000ff1f222ffff22f110042784ff7872f42ee2f070f2ef000feff2226422222462012f267172ff271728227707fff707288
77777777000000000000000000000000ff1f27d2ff2d7210000289fff8972f44ee2f000fffff0f2effff27a2fff2a7202fff26772ff267722ff20c7fff0c6228
00007770000000000000000000000000ffff2717ff217200044f22ffff22ff42ee2ff0ffffff0f2e2fff2222fff2222012fff212ffff222fffff222fff222ff8
0007770000000000000000000000000011fff222fff22f00004fff2fffffff420e2fff222222f2e02ffffffff22fff20002fffffffff2ff02ffffffff2fffff2
00777000000000000000000000000000011ffffff22fff00044fff22ffffff420ee2ffeeeeeff2e002ff2fffffffff200002ffffff22fff022ffffffffffff22
077700000000000000000000000000000002fffffffff200000ffffffffff42400ee20ffffff002e002ffff2222fff2000002fffffffff00002ffffffffff222
7777777700000000000000000000000000002fff222ff000004fff2222f44240000e2000099fffa000222ffffffff200000222ff1222f0000002fff222ff2222
77777777000000000000000000000000000002ffffff20000004ffffffff240000002aafffffffaf02222222222220000022222ffffff200000002ffff202020
__gff__
0000000000000000002121210021030300000000000000004a212121060a12090000000000000000122121210303031100000000000000000021212103030303464a5200860000000000000000000000000000000000000000002121000000210000002100000000000005050000000500000005000000000000050500000005
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000d000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000d000000000d0d00000d0000000d0000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000d001a0a5e0a0a0a0a0a0a0a0a2a000d000d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000d001a0a091f7f6f6f6f6f6f6f1f1f0b2a000d0d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00001a091f2f6f7f6f6f1f1f1f6f6f6f1f0b2a0d000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d0d00291f402f1f7f6f1f1d1f1f1f1f6f1f1f2b00000d0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d00291f3f2f6f7f1f1f1f1f1f1f1f6f6f1f0b2a00000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000d29423f2f1d7f1f1f1f1f1f1f1f1f6f1f1f0b2a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d00296f3f2f6f7f6f1f1f2c2d2d2d2d2d2d2e1f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d000d296f3f2f1d7f6f6f6f3f1f1f6c6d6d6d0e6d5c000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d0d00296f3f2f6f7f6f1f6f3f1f1f7f6f2f6f3f1d2b000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000291f3c3d3d0f3d3d3d3e6f1f7f6f466f3f1b3b000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d00291f1f6f1d7f6f6f1f6f6f6f7f6f6f6f3f2b000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000393a3a3a3a5f196f6f6f6f6f7f1f443d3e2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d000000000d0000296f6f6f6f6f7f1f1f1f1b3b000d000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000393a3a3a3a3a5f191f1b3b00000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000d0000000d000000000d000000393a3b000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000d000000000d000000000d0000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d00000000000000000d000000000d000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000d0000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000013550215502d5503a5503f5503f5503d5503750032500335002e500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000300002865025650216401e6401664011640096300063000630006300003020600266001e600006001260009600066000060000600006000060000600006000060000600006000060000600006000060000600
000100001905032050240500d05003050070500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
