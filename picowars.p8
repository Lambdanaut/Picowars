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

unit_infantry, unit_mech, unit_recon, unit_apc, unit_artillery, unit_tank, unit_rocket, unit_war_tank = "infantry", "mech", "recon", "apc", "artillery", "tank", "rocket", "war tank"
  
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
sfx_campaign_victory = 3

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
p_slydy_hachi = 230
p_hachi = 198
p_storm = 228
p_jethro = 196


-- music
team_index_to_music = {
  31, 0, 44, 15
}

-- team icons
team_index_to_team_icon = {
  192, 208, 193, 209
}

team_index_to_team_name = {"orange star★", "blue moon●", "green earth🅾️", "pink quasar░"}

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
main_menu_options = {"campaign mode", "verses mode"}

-- verses menu
vs_mode_option_selected = 0
map_index_selected = 0
ai_index_selected = 0
p1_co_index_selected = 0
p2_co_index_selected = 0
map_index_options = {"arbor island", "lil highland", "big island", "crossover"}
ai_index_options = {"vs ai", "vs human", "ai vs ai"}

-- fadeout variables
fading = 0

-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame
memory_i = starting_memory
campaign_level_index = 1

-- dialogue defaults
dialogue_timer = 0
ongoing_dialogue = {}
current_dialogue_index = 1
allow_dialogue_skipping = false


function _init()
  music(music_splash_screen, 0, music_bitmask)

  -- setup cartdata
  cartdata("picowars") 

  -- load save
  read_save()

  -- make commanders for vs mode
  -- done after reading the save because we have to see what's available
  commanders_p1 = make_vs_commanders()
  commanders_p2 = make_vs_commanders()

  -- read match result
  read_match_result()

  -- read match metadata
  read_match_meta()
  clear_match_meta()  -- reset match meta memory bits

  if match_meta_coming_from_match then
    if match_meta_is_campaign_mission then
      if match_result_reason == 1 then sfx(sfx_campaign_victory) end
      init_campaign()
    end
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

      local sprite_blue_moon = 208
      local sprite_green_earth = 193
      local sprite_pink_quasar = 209

      if campaign_level_index <= 2 then sprite_blue_moon = 224 end
      if campaign_level_index <= 5 then sprite_green_earth = 224 end
      if campaign_level_index <= 5 then sprite_pink_quasar = 224 end

      spr(192, 47, 38)
      spr(sprite_blue_moon, 56, 38)
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
    -- map selection
    if btnp_left then 
      map_index_selected -= 1 
      sfx(0)
    elseif btnp_right then 
      map_index_selected += 1
      sfx(0)
    end
  elseif vs_mode_option_selected == 1 then 
    -- vs human/ai selection
    if btnp_left then 
      ai_index_selected -= 1 
      sfx(0)
    elseif btnp_right then
      ai_index_selected += 1 
      sfx(0)
    end
  elseif vs_mode_option_selected == 2 then 
    -- p1 commander selection
    if btnp_left then 
      p1_co_index_selected -= 1 
      sfx(0)
    elseif btnp_right then
      p1_co_index_selected += 1 
      sfx(0)
    end

  elseif vs_mode_option_selected == 3 then 
    -- p2 commander selection
    if btnp_left then 
      p2_co_index_selected -= 1 
      sfx(0)
    elseif btnp_right then
      p2_co_index_selected += 1 
      sfx(0)
    end
  end

  if btnp_down then
    vs_mode_option_selected += 1
    sfx(0)
  elseif btnp_up then
    vs_mode_option_selected -= 1
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

    local co1 = commanders_p1[p1_co_index_selected+1]
    local co2 = commanders_p2[p2_co_index_selected+1]

    -- write all commander and unit data to memory
    commander_teams = write_assets(current_map, {co1, co2}, players_human)

    printh(commander_teams[1])
    printh(commander_teams[2])

    write_match_meta(0, commander_teams[1], commander_teams[2], co1.index, co2.index)
  elseif btnp5 then
    -- back to main menu
    sfx(1)
    menu_index = 1
  end

  map_index_selected = map_index_selected % #vs_map_index_mapping
  ai_index_selected = ai_index_selected % #ai_index_options
  p1_co_index_selected = p1_co_index_selected % #commanders_p1
  p2_co_index_selected = p2_co_index_selected % #commanders_p2
  vs_mode_option_selected = vs_mode_option_selected % 4
end

function init_campaign()
  if campaign_level_index < 1 then campaign_level_index = 1 end
  current_level = campaign_levels[campaign_level_index]
end

function update_campaign()
end

function update_victory_defeat_menu()
  local victory_dialogue_complete = current_dialogue_index >= #ongoing_dialogue

  if btnp4 and victory_dialogue_complete then 
    sfx(1)

    if match_meta_is_campaign_mission then
      if match_result_reason == 1 then
        -- campaign level victory. increment campaign counter, save game, and continue to next mission.

        -- unlock commanders
        for lvl in all(campaign_levels) do
          if lvl.index <= campaign_level_index and lvl.co_unlocks then
            commanders[lvl.co_unlocks.index].available = true
          end
        end

        campaign_level_index += 1

        if campaign_level_index <= #campaign_levels then
          -- start next campaign mission
          init_campaign()
          write_save()
          menu_index = 3
        else
          -- final level
          -- do endgame credits
          campaign_level_index -= 1
          write_save()
          load("credits.p8")
        end
      else
        sfx(1)
        menu_index = 1
      end
    else
      -- not campaign mission. return to main menu
      sfx(1)
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
  -- draw map and ai/human selection
  for y = 0, 1 do
    for x = 0, 1 do
      spr(last_checked_time*2 % 2, 24 + x*70, 54 + y*20, 1, 2, x==1)
    end
  end
  if vs_mode_option_selected < 2 then
    -- draw selected
    rectfill(38, 58 + (vs_mode_option_selected) * 19, 86, 64 + (vs_mode_option_selected) * 19, 4)
  end

  print(map_index_options[map_index_selected+1], 39, 59, 7)
  print(ai_index_options[ai_index_selected+1], 53 + ai_index_selected*-6, 78, 7)

  -- draw commander selection
  local co1 = commanders_p1[p1_co_index_selected+1]
  local co2 = commanders_p2[p2_co_index_selected+1]
  spr(co1.sprite, 35, 105, 2, 2)
  spr(co2.sprite, 78, 105, 2, 2)

  local p1_outline = 0
  local p2_outline = 0
  if vs_mode_option_selected == 2 then
    p1_outline = 4
  elseif vs_mode_option_selected == 3 then
    p2_outline = 4
  end

  print_outlined("p1:" .. co1.name, 24, 98, 7, p1_outline)
  print_outlined("p2:" .. co2.name, 70, 98, 7, p2_outline)
end

function draw_campaign()
  -- draw map
  cls(12)
  map(0, 31, current_level.map_pos[1], current_level.map_pos[2], 16, 18)

  if not active_dialogue_coroutine then
    allow_dialogue_skipping = true
    ongoing_dialogue = current_level.dialogue
    active_dialogue_coroutine = cocreate(dialogue_coroutine)

  elseif costatus(active_dialogue_coroutine) == dead_str then
    -- dialogue over. run campaign mission

    -- write the map, commander and unit data to memory
    write_assets(current_level.map, {current_level.co_p1, current_level.co_p2}, {true, false})

    -- write match meta to memory
    write_match_meta(
      current_level.index,
      current_level.co_p1.team_index,
      current_level.co_p2.team_index,
      current_level.co_p1.index,
      current_level.co_p2.index)

    fadeout()

  elseif active_dialogue_coroutine then
    coresume(active_dialogue_coroutine)
  end

end

function draw_victory_defeat_menu()
  cls(7)

  local continue_text = "press ❎ or 🅾️ to continue"

  if match_meta_is_campaign_mission then
    continue_text = "press ❎ or 🅾️ to save\n\n     and continue."
    -- campaign level. 
    if match_result_reason == 1 then
      local speed = calculate_speed(match_result_turn_count, current_level.perfect_turns)
      local technique = calculate_technique(match_result_units_built[1], match_result_units_lost[1])
      local score = (speed + technique) / 2
      print_double("!!!victory!!!", 38, 6, 3, 11) 
      line(10, 15, 118, 15, 3)
      rectfill(10, 16, 118, 48, 6)
      print_double("speed: " .. to_rank(speed), 38, 22, 3, 11) 
      print_double("technique: " .. to_rank(technique), 38, 30, 3, 11) 
      print_double("total rank: " .. to_rank(score), 38, 38, 3, 11) 

    else
      print_double("defeat", 53, 44, 9, 8)
    end
  else
    -- not campaign level. 
    local victor = match_meta_p1_team_index
    if match_result_reason == 2 then
      victor = match_meta_p2_team_index
    end
    print_double("victory for " .. team_index_to_team_name[victor], 10, 8, 3, 11) 
  end

  if last_checked_time % 2 > 1 then
    print_double(continue_text, 14, 55, 10, 11) 
  end

  draw_victory_dialogue()

end

function draw_victory_dialogue()
  if not active_victory_dialogue_coroutine then
    if match_result_reason == 1 then 
      ongoing_dialogue = match_meta_p1_commander.dialogue
      if current_level and current_level.victory_dialogue then
        merge_tables(ongoing_dialogue, current_level.victory_dialogue)
      end
    else
      ongoing_dialogue = match_meta_p2_commander.dialogue
    end
    active_victory_dialogue_coroutine = cocreate(dialogue_coroutine)
  elseif costatus(active_victory_dialogue_coroutine) == dead_str then

  elseif active_victory_dialogue_coroutine then
    coresume(active_victory_dialogue_coroutine)
  end
end

-- coroutines
function dialogue_coroutine()
  local last_speaker_i
  current_dialogue_index = 0

  while current_dialogue_index < #ongoing_dialogue + 1 do

    current_dialogue_index += 1
    local next_dialogue = ongoing_dialogue[current_dialogue_index]

    if last_speaker_i and last_speaker_i ~= next_dialogue[1].index then
      -- play commander switchout animation
      for i = 1, 10 do
        draw_dialogue("", 0, -(i / 2)^2)
        yield()
      end
    end
    current_dialogue = next_dialogue

    if not last_speaker_i or last_speaker_i ~= next_dialogue[1].index then
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
        dialogue_timer = -0.2
      elseif next_char == "," or next_char == "∧" then
        dialogue_timer = -0.1
      end

      while dialogue_timer < 0.0333 do
        draw_dialogue(current_dialogue[2], dialogue_str_i)

        if (btnp4 or btnp5) and dialogue_str_i > 1 then
          dialogue_str_i = #current_dialogue[2]
          yield()
          break
        end

        yield()

      end

    end

    local skip_dialogue
    local skip_dialogue_timer
    while not btnp4 do
      skip_dialogue_timer = 0
      draw_dialogue(current_dialogue[2])
      print("🅾️", 120, 122, 0)
      yield()
      while btn(5) and allow_dialogue_skipping do
        skip_dialogue_timer += delta_time

        if skip_dialogue_timer >= 2 then
          skip_dialogue = true
          break
        end

        cls(0)
        print_double("hold ❎ to skip dialogue", 16, 60, 7, 5)
        rectfill(10, 70, 118, 80, 5)
        local fill_width = (skip_dialogue_timer / 2) * 106 + 11
        rectfill(11, 71, fill_width, 79, 7)

        yield()
      end
      if skip_dialogue then break end
    end
    if skip_dialogue then break end

    last_speaker_i = current_dialogue[1].index

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
    set_palette(current_dialogue[1].team_index)
    print_double(str, 22, str_i, 0, 8)
    pal()
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

function camp_map_2()
  local m = {}

  m.name = "sami surprise"
  m.r = {22, 0, 28, 17}
  m.bg_color = 12

  m.load_external = 1

  return m
end

function camp_map_3()
  local m = {}

  m.name = "conrad's wall"
  m.r = {58, 18, 30, 13}
  m.bg_color = 3

  m.load_external = 1

  return m
end

function camp_map_4()
  local m = map_arbor_island()

  m.name = "hachi's return"

  return m
end

function camp_map_5()
  local m = {}

  m.name = "glitch gorge"
  m.r = {51, 0, 12, 18}
  m.bg_color = 3

  m.load_external = 1

  return m
end

function camp_map_6()
  local m = {}

  m.name = "roundabout way"
  m.r = {20, 16, 30, 14}
  m.bg_color = 12

  m.load_external = 1

  return m
end

function camp_map_7()
  local m = {}

  m.name = "slydys bout"
  m.r = {63, 0, 31, 18}
  m.bg_color = 3

  m.load_external = 1

  return m
end

function camp_map_8()
  local m = {}

  m.name = "black hole"
  m.r = {95, 0, 35, 32}
  m.bg_color = 12

  m.load_external = 1

  return m
end

function camp_map_9()
  local m = {}

  m.name = "cat's claws"
  m.r = {0, 21, 12, 25}
  m.bg_color = 12

  m.load_external = 0

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
  unit.travel = 11
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
function make_sami()
  local co = {}

  co.index = 1
  co.name = "sami"
  co.sprite = p_sami
  co.team_index = 1  -- orange star
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = true
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "score one for the grunts!"}}

  co.units = make_units()

  -- sami's infantry, mechs, and apc travels further
  co.units[unit_index_infantry].travel += 1
  co.units[unit_index_mech].travel += 1
  co.units[unit_index_apc].travel += 1

  -- sami's infantry and mechs have a +5 to their capture rate
  co.units[unit_index_infantry].capture_bonus += 5
  co.units[unit_index_mech].capture_bonus += 5

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

  co.index = 2
  co.name = "hachi"
  co.sprite = p_hachi
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "i may be old, but i can still rumble!"}}

  co.units = make_units()

  -- hachi's non-infantry and non-mech units cost 15% less
  for i=3, #co.units do
    co.units[i].cost = flr(co.units[i].cost * 0.85)
  end

  return co
end
co_hachi = make_hachi()

function make_slydy_hachi()
  local co = {}

  co.index = 3
  co.name = "hachi"
  co.sprite = p_slydy_hachi
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "I ▒▒M░ay be old, but …░I can s ti…░ll r ▒▒mble!"}}

  co.units = make_units()

  -- slydy-hachi's non-infantry and non-mech units cost 15% less
  for i=3, #co.units do
    co.units[i].cost = flr(co.units[i].cost * 0.85)
  end

  return co
end
co_slydy_hachi = make_slydy_hachi()

function make_bill()
  local co = {}

  co.index = 4
  co.name = "bill"
  co.sprite = p_bill
  co.team_index = 2  -- blue moon
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = true
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "lucks on our side!"}}

  co.units = make_units()

  -- bill's units have 10% more luck
  for i=1,#co.units do
    co.units[i].luck_max = 2
  end

  return co
end
co_bill = make_bill()

function make_alecia()
  local co = {}

  co.index = 5
  co.name = "alecia"
  co.sprite = p_alecia
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "you thought i'd give up that easy?"}}

  co.units = make_units()

  -- alecia's units are healed by 3 by structures
  for unit in all(co.units) do
    unit.struct_heal_bonus = 1

    -- all of alecia's units have 10% less firepower
    for i=1, #unit.damage_chart do
      unit.damage_chart[i] *= 0.9
    end
  end

  return co
end
co_alecia = make_alecia()

function make_conrad()
  local co = {}

  co.index = 6
  co.name = "conrad"
  co.sprite = p_conrad
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "justice is the intention."}}

  co.units = make_units()

  for unit in all(co.units) do
    -- conrads's units are only healed by 1 by structures
    unit.struct_heal_bonus = -1

    -- all of conrads units have 15% more firepower
    for i=1, #unit.damage_chart do
      unit.damage_chart[i] *= 1.15
    end
  end

  return co
end
co_conrad = make_conrad()

function make_guster()
  local co = {}

  co.index = 7
  co.name = "guster"
  co.sprite = p_guster
  co.team_index = 3  -- green earth
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "my calculations were nominal."}}

  co.units = make_units()

  -- guster's ranged units have +1 range
  co.units[5].range_max += 1
  co.units[7].range_max += 1

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

function make_glitch()
  local co = {}

  co.index = 8
  co.name = "glitch"
  co.sprite = p_glitch
  co.team_index = 4  -- pink quasar
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "▒▒▒▒▒▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"}}

  co.units = make_units()

  -- glitch's unit graphics are glitched
  for i=1,#co.units do
    co.units[i].sprite = flr(rnd(59)+134)
  end

  return co
end
co_glitch = make_glitch()

function make_slydy()
  local co = {}

  co.index = 9
  co.name = "slydy"
  co.sprite = p_slydy
  co.team_index = 4  -- pink quasar
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "the world is a cleaner place."}}

  co.units = make_units()

  for unit in all(co.units) do
    -- slydy's units cost 15% more
    if unit.index > 2 then
      unit.cost = ceil(unit.cost * 1.15)
    end

    -- all of slydy's units have 30% more firepower
    for i=1, #unit.damage_chart do
      unit.damage_chart[i] *= 1.3
    end
  end

  return co
end
co_slydy = make_slydy()

function make_storm()
  local co = {}

  co.index = 10
  co.name = "storm"
  co.sprite = p_storm
  co.team_index = 4  -- pink quasar
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {{co, "you've taken everything from me.", true}}

  co.units = make_units()

  -- storm's units have +1 travel
  for i=1,#co.units do
    co.units[i].travel += 1
  end

  return co
end
co_storm = make_storm()

function make_jethro()
  local co = {}

  co.index = 11
  co.name = "jethro"
  co.sprite = p_jethro
  co.team_index = 3
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]
  co.dialogue = {
    {co, "what is best in life?"},
    {co, "to crush your enemies, see them driven before you,", true},
    {co, "and to hear the lamen- tation of their women.", true}
  }

  co.units = make_units()

  -- jethro's infantry and mechs have a +10 to their capture rate
  co.units[unit_index_infantry].capture_bonus += 10
  co.units[unit_index_mech].capture_bonus += 10

  return co
end
co_jethro = make_jethro()

function make_commanders()
  return {
    make_sami,
    make_hachi,
    make_slydy_hachi,
    make_bill,
    make_alecia,
    make_conrad,
    make_guster,
    make_glitch,
    make_slydy,
    make_storm,
    make_jethro 
  }
end

function instantiate_commanders(cos)
  local new_cos = {}
  for co in all(cos) do
    add(new_cos, co())
  end
  return new_cos
end

function make_vs_commanders()
  local cos_to_add = instantiate_commanders(make_commanders())
  local vs_cos = {}
  for co in all(cos_to_add) do
    if commanders[co.index].available then
      add(vs_cos, co)
    end
  end
  return vs_cos
end

commanders = instantiate_commanders(make_commanders())

-- campaign levels
function level_1()
  local l = {}

  l.index = 1
  l.map = camp_map_1()
  l.map_pos = {35, 30}
  l.co_p1 = make_hachi()
  l.co_p2 = make_bill()
  l.perfect_turns = 10

  l.dialogue = {
    {co_bill, "i'm here. i made it."},
    {co_bill, "i'll make orange star pay for what they've done."},
    {co_bill, "..."},
    {co_bill, "but this is too easy.", true},
    {co_bill, "hachi, get your ass out here!"},
    {co_hachi, "oh hey bill! i didn't hear you knock."},
    {co_bill, "cut it hachi. do i look like i'm here for your jokes?"},
    {co_hachi, "is everything okay bill? what's going on?", true},
    {co_bill, "WHAT'S GOING ON.....?"},
    {co_bill, "what's going on?!", true},
    {co_bill, "after all we've been through together,", true},
    {co_bill, "you really are sick hachi. take responsibility and die.", true},
  }

  return l
end

function level_2()
  local l = {}

  l.index = 2
  l.map = camp_map_2()
  l.map_pos = {10, 10}
  l.co_p1 = make_sami()
  l.co_p2 = make_alecia()
  l.perfect_turns = 10
  l.co_unlocks = co_alecia

  l.dialogue = {
    {co_hachi, "what could that have been about...", true},
    {co_sami, "sir!"},
    {co_sami, "first commanding officer sami domino reporting in!"},
    {co_hachi, "sami eh?", true},
    {co_hachi, "well you sure as hell picked odd times to start fighting wars!"},
    {co_hachi, "what's your specialty commander?"},
    {co_sami, "infantry specialist first class sir!"},
    {co_hachi, "drop the \"sir\", sami. you're a fellow commander now. call me hachi."},
    {co_sami, "yes si-..."},
    {co_sami, "r... yes hachi"},
    {co_hachi, "you'll get it."},
    {co_alecia, "a new recruit eh?"},
    {co_alecia, "what luck. you're going down.", true},
    {co_hachi, "sami, get out there. you've got this."},
    {co_sami, "i'm on it, hachi!"},
    {co_hachi, "ayeee"},
    {co_hachi, "...sami's units are a bit more expensive than mine, but..."},
    {co_hachi, "with more cities captured, she'll do just fine."},
    {co_hachi, "in the meantime i need to figure out what this invasion is about.", true},
  }

  return l
end

function level_3()
  local l = {}

  l.index = 3
  l.map = camp_map_3()
  l.map_pos = {-20, 20}
  l.co_p1 = make_sami()
  l.co_p2 = make_conrad()
  l.perfect_turns = 10
  l.co_unlocks = co_conrad

  l.dialogue = {
    {co_alecia, "orange star bitch.", true},
    {co_alecia, "you have no idea what your general is capable of.", true},
    {co_sami, "er? you mean hachi..?"},
    {co_alecia, ".. YOU really HAVE NO IDEA. DO YOU..?", true},
    {co_conrad, "that's far enough sami."},
    {co_conrad, "your march towards blue moon territory ends here."},
    {co_sami, "look dude, i'm just defending our land from y o u r invasion.", true},
    {co_conrad, "is that how you see it?"},
    {co_sami, "yes!", true},
    {co_conrad, "well, regardless."},
    {co_conrad, "prepare to hit a brick wall."},
  }

  return l
end

function level_4()
  local l = {}

  l.index = 4
  l.map = camp_map_4()
  l.map_pos = {-44, -20}
  l.co_p1 = make_bill()
  l.co_p2 = make_slydy_hachi()
  l.perfect_turns = 10

  l.dialogue = {
    {co_sami, "i'm doing pretty well.. i haven't even needed hachi's aid."},
    {co_bill, "...hachi isn't here with you?"},
    {co_sami, "gah, bill! the gigs up.", true},
    {co_sami, "what's going on? why the invasion of orange star territory?", true},
    {co_bill, "..."},
    {co_bill, "sami..."},
    {co_bill, "where is hachi right now?", true},
    {co_sami, "er.. he's investigating the invasion."},
    {co_bill, "no, sami, that's what y o u are doing. what is h a c h i doing?"},
    {co_sami, ".. i don't know."},
    {co_sami, "why does it matter?"},
    {co_bill, "sami, our feud isn't with you."},
    {co_bill, "it's becoming clear that you're just another one of his pawns."},
    {co_bill, "you need to understand."},
    {co_bill, "hachi isn't who you think he is."},
    {co_bill, "he's a monster.",},
    {co_slydy_hachi, "oh hey bill! i didn't hear you knock.", true},
    {co_sami, "hachi! finally, we can sort all of this out."},
    {co_slydy_hachi, "is eve▒ything okay bilL? what's g▒ing on?", true},
    {co_bill, "sami, you should head home if you know what's good for you.", true},
    {co_slydy_hachi, "wH▒ts G▒OING on BILL?"},
    {co_bill, "i have a demon to slay."},
  }

  return l
end

function level_5()
  local l = {}

  l.index = 5
  l.map = camp_map_5()
  l.map_pos = {-40, -50}
  l.co_p1 = make_guster()
  l.co_p2 = make_glitch()
  l.perfect_turns = 10
  l.co_unlocks = co_guster

  l.dialogue = {
    {co_slydy_hachi, "▒▒…,∧. ▒…░▒M░… .▒…∧  ░▒…. i'll be back for you ░▒ bill. ░▒ "},
    {co_sami, "..."},
    {co_sami, "WHAT THE hell"},
    {co_sami, "WHAT was THAT?"},
    {co_bill, "CLEARLY NOT HACHI..."},
    {co_guster, "...", true},
    {co_guster, "h-- hello there fellow commanders.."},
    {co_sami, "guster? "},
    {co_guster, "my brother heard that orange star was in the area.."},
    {co_guster, "and sent me in to investi- gate.."},
    {co_guster, "he may have mentioned that you recently became an orange star co sami.", true},
    {co_sami, "this fucking guy ", true},
    {co_bill, "??? "},
    {co_guster, "i've been sami's partner in the past."},
    {co_sami, "yeah, well that's `ex- partner` now, dude. ", true},
    {co_guster, "look, i came to help. i think we both have bigger fish to fry.", true},
    {co_guster, "blue moon isn't the only one dealing with... anomalies. "},
    {co_guster, "green earth has also been under siege by glitchy automata."},
    {co_sami, "glitchy automata?"},
    {co_guster, "abhorrencies generated from uncertaincies in the quantum foam."},
    {co_bill, "eh?"},
    {co_guster, "scary fucking monsters from hell."},
    {co_bill, "oh, yeah, that sounds about right."},
    {co_glitch, "who the f░▒ck d o you th^nk youre t…lking░▒ on about like that"},
    {co_glitch, "i'll f░▒ck your soul^", true},
    {co_sami, "oh my.."},
    {co_guster, "i've got this fucker."},
    {co_guster, "eat my tactical long ranged lead."},
  }

  return l
end

function level_6()
  local l = {}

  l.index = 6
  l.map = camp_map_6()
  l.map_pos = {-8, -70}
  l.co_p1 = make_alecia()
  l.co_p2 = make_slydy()
  l.perfect_turns = 8
  l.co_unlocks = co_glitch

  local pink_hachi = make_slydy_hachi()
  pink_hachi.team_index = 4

  l.dialogue = {
    {co_glitch, "sh░▒t", true},
    {co_glitch, "creator st▒rm must hear …about this░"},
    {co_guster, "creator.. storm?"},
    {co_sami, "that's what i heard too.. i think."},
    {co_conrad, "hey guys. "},
    {co_conrad, "we've been cleaning up the last of the glitches in blue moon."},
    {co_conrad, "sorry we couldn't join sooner."},
    {co_conrad, "and sami, i apologize for my hostility back in blue moon."},
    {co_conrad, "you aren't the enemy here."},
    {co_conrad, "we're all in this to- gether."},
    {co_slydy, "how touching"},
    {co_alecia, "ugh, what is that thing?", true},
    {co_slydy, "\"thing\"? that is no way to refer to"},
    {co_slydy, "p^e^n^u^l^t^i^m^a^t^e b^e^a^u^t^y"},
    {co_alecia, "those eyes...", true},
    {co_alecia, "i know them...", true},
    {co_slydy, "yes dear"},
    {pink_hachi, "it is i. h▒chi"},
    {co_alecia, "you are the monster that burnt my homeland to the ground.", true},
    {co_slydy, "i am simply reforming your homeland."},
    {co_slydy, "changing it into something greater."},
    {co_slydy, "shaping it into my own perfect image."},
    {co_slydy, "COVERING IT IN glitch."},
    {co_alecia, "shut the fuck up and die.", true},
    {co_alecia, "guys i've got this one.", true},
    {co_alecia, "it's personal.", true},
  }

  return l
end

function level_7()
  local l = {}

  l.index = 7
  l.map = camp_map_7()
  l.map_pos = {24, -70}
  l.co_p1 = make_hachi()
  l.co_p2 = make_slydy()
  l.perfect_turns = 10
  l.co_unlocks = co_slydy

  l.dialogue = {
    {co_slydy, "that was filthy"},
    {co_slydy, "that was a filthy way to play."},
    {co_slydy, "you're still so dirty and you all need to be cleaned."},
    {co_hachi, "hey team!"},
    {co_sami, "yeck! it's back!", true},
    {co_bill, "no sami, wait, this is the real hachi!"},
    {co_hachi, "heh, i should hope so!"},
    {co_hachi, "check it, i don't have grody giant lips or anything."},
    {co_guster, "he checks out. resonance scanning returns nil corrupt vectors."},
    {co_hachi, "that's right buddy! I'M ALL NATURAL hachi. "},
    {co_sami, "that's a relief. i kinda figured uh.."},
    {co_sami, "you were dead.."},
    {co_conrad, "hachi i can't believe you're alive.", true},
    {co_hachi, "you alright there big guy..? ", true},
    {co_conrad, "i'm... i'll be okay.", true},
    {co_alecia, "so what's the sitch, hachi?", true},
    {co_hachi, "well, i unearthed some intel while i was out."},
    {co_hachi, "this creature slydy here, and the others you've faced,"},
    {co_hachi, "they're all the creations of a very bright, mis- guided young man.", true},
    {co_hachi, "storm.", true},
    {co_hachi, "to shut down this glitch blight spreading across the land..", true},
    {co_hachi, "we need to apprehend him and shut down his factory. ", true},
    {co_hachi, "and i've pinpointed his exact location."},
    {co_sami, "what are we waiting for then? let's take him down!"},
    {co_slydy, "..."},
    {co_slydy, "i'm still here you know."},
    {co_slydy, "and none of you glitchless freaks are going to set a foot near creator."},
    {co_slydy, "today marks the beginning of a clean world."},
  }

  return l
end

function level_8()
  local l = {}

  l.index = 8
  l.map = camp_map_8()
  l.map_pos = {45, -40}
  l.co_p1 = make_hachi()
  l.co_p2 = make_storm()
  l.perfect_turns = 35
  l.co_unlocks = co_storm

  l.dialogue = {
    {co_bill, "is it dead..?"},
    {co_guster, "i think so. i think we've done it."},
    {co_storm, "slydy?"},
    {co_storm, "..slydy what have they done to you?"},
    {co_slydy, "creator.. i have failed you", true},
    {co_slydy, "i tried my best to cleanse the ones that may hurt us.", true},
    {co_slydy, "but the world is darker than i ever knew.", true},
    {co_storm, "shhh..."},
    {co_storm, "rest now.."},
    {co_storm, "you've done all you could have."},
    {co_slydy, ",, , , ,, ▒▒…, ∧. ▒…░▒M░… .▒…∧  ░ ▒…", true},
    {co_conrad, "storm, in the name of the united allied forces, drop your arms."},
    {co_storm, "...", true},
    {co_storm, "...you think this is over?", true},
    {co_storm, "you've taken everything from me and you think i'll just give up?", true},
    {co_hachi, "son, it's your only way out. our forces have reached your hq.", true},
    {co_storm, "all you've succeeded in doing is corner a wild animal", true},
    {co_storm, "a wild animal with nothing left to live for.", true},
    {co_storm, "right now, you are the ones in danger.", true},
  }

  return l
end

function level_9()
  local l = {}

  l.index = 9
  l.map = camp_map_9()
  l.map_pos = {45, -40}
  l.co_p1 = make_bill()
  l.co_p2 = make_jethro()
  l.perfect_turns = 31
  l.co_unlocks = co_jethro

  l.dialogue = {
    {co_sami, "we did it!"},
    {co_alecia, "good riddance."},
    {co_conrad, "the glitch generators have been dismantled."},
    {co_guster, "soon this region will return to normalcy."},
    {co_bill, "..."},
    {co_bill, "yeah but guys, storm escaped."},
    {co_hachi, "there'll always be an enemy out there, plotting evil."},
    {co_hachi, "i believe we have earned ourselves a respite from this war."},
    {co_alecia, "that sounds nice.."},
    {co_conrad, "to peace!"},
    {co_hachi, "to peace!"},
    {co_jethro, ".."},
    {co_jethro, "mrow???"},
    {co_bill, "uh... guys?"},
    {co_bill, "who brought the cat?", true},
    {co_conrad, "oh my god he's so cute", true},
    {co_bill, "really now, i'm highly alergic and...", true},
    {co_jethro, "mrow!!!", true},
    {co_conrad, "oh my god bill he's got those lil epaulettes on his shoulders.", true},
    {co_jethro, "mrow!!", true},
    {co_bill, "argh! get him off me! i'm -- *sneezes* i can't deal", true},
    {co_hachi, "sorry bill, this is your war to fight.", true},
    {co_hachi, "anyone else up for some war room? i've got new battle maps."},
    {co_sami, "i'm in!"},
    {co_bill, "guys!?", true},
    {co_alecia, "me too!"},
    {co_jethro, "mrow!!", true},
    {co_bill, "aaahghhhggg", true},
  }

  l.victory_dialogue = {
    {co_bill, "...", true},
    {co_bill, "it's not over yet, is it..?", true},
    {co_jethro, "no, bill."},
    {co_jethro, "now we roll the credits."},
    {co_bill, "oh my god.", true},
  }

  return l
end

-- index of all campaign levels 
campaign_levels = {level_1(), level_2(), level_3(), level_4(), level_5(), level_6(), level_7(), level_8(), level_9()}

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
  -- write all assets to be loaded by engine.p8
  -- game_map is a map object created by a make_map function
  -- game_commanders is a 2 indexed table of both of the commanders
  -- team_humans is a 2 indexed table indicating whether the player is a human or ai
  -- team_indexes is an optional 2 indexed table indicating what team each player should be on (orange star, blue moon.. etc)

  -- returns the resulting commanders team indexes in a tuple {team1index, team2index}

  memory_i = starting_memory
  if not team_indexes then team_indexes = {} end
  if game_commanders[1].team_index == game_commanders[2].team_index then 
    game_commanders[2].team_index = max(1, (game_commanders[2].team_index + 1) % 5)
  end
  for i=1, 2 do
    write_co(game_commanders[i], team_humans[i], team_indexes[i])
  end
  write_map(game_map)

  return {game_commanders[1].team_index, game_commanders[2].team_index}
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
end

function delete_save()
  -- utility for deleting a save
  for i=0, 63 do
    dset(i, 0)
  end
end

function read_match_meta()
  memory_i = 0x5dc0

  match_meta_coming_from_match = peek_increment() == 1
  match_meta_level_index = peek_increment()
  match_meta_is_campaign_mission = match_meta_level_index > 0
  match_meta_p1_team_index = peek_increment()
  match_meta_p2_team_index = peek_increment()
  match_meta_p1_commander = commanders[peek_increment()]
  match_meta_p2_commander = commanders[peek_increment()]

  if match_meta_coming_from_match and match_meta_is_campaign_mission then
    campaign_level_index = match_meta_level_index
  end
end

function write_match_meta(level_index, p1_team_index, p2_team_index, p1_commander_index, p2_commander_index)
  -- writes metadata about a match to be read by loader after the match
  memory_i = 0x5dc0

  poke_increment(1)  -- bool to indicate we're entering a match
  poke_increment(level_index)
  poke_increment(p1_team_index)
  poke_increment(p2_team_index)
  poke_increment(p1_commander_index)
  poke_increment(p2_commander_index)
end

function clear_match_meta()
  -- clears match metadata. run on loader startup
  memory_i = 0x5dc0

  while memory_i < 0x5ddd do
    poke_increment(0)
    memory_i += 1
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

function print_double(str, x, y, col, double_color)
  for a=x-1,x+1 do
    for b=y-1,y+1 do
      print(str,a,b,double_color)
    end
  end
  print(str, x, y, col)
end

function merge_tables(t1, t2)
  -- merges the second table into the first
  i = #t1 + 1
  for _, v in pairs(t2) do 
    t1[i] = v 
    i += 1
  end
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

function start_map()
  -- start a map
  load("engine.p8")
end

function calculate_speed(turns_completed, min_perfect_turns)
  return min(100, 100 + min_perfect_turns - turns_completed)
end

function calculate_technique(units_built, units_lost)
  return min(100, 100 * (units_built - units_lost / 2) / units_built)
end

function to_rank(score)
  rank_mapping = {'a','b','c','d','f'}
  local rank = rank_mapping[min(5, 11 - ceil(score/10))]
  if score >= 100 then rank = 's' end
  return rank
end


__gfx__
0000000700000001000000000000000000000000000000000000000033aaaa33331111330000004400000000220000000000000000f00000566666555ccccc63
00000077000000170000000000000000000000000000000000000000332a2a3333616133000000440000000022000000000000000f4400f0c66666cc5c5c5c66
00000777000001d70000000000000000000000000000000000000000eeeaaeeeccc11ccc0000004400000000220000000000000072427f425667665c66666666
0000777d00001dd70000000000000000000000000000000000000000e2ea2e2ec6c16c6c0000004400000000220000000000000007270722c66766cc66666666
000777dd0001ddd70000000000000000000000000000000000000000eeeaaeeeccc11ccc00000044000000002200000000dddd00007f40775666665c66776677
00777ddd001dddd70000000000000000000000000000000000000000e2ea2e2ec6c16c6c0000004400000000220000000ddddd5007244270c66666cc66666666
0777dddd01ddddd70000000000000000000000000000000000000000eeeaaeeeccc11ccc0000044400000000222000000ddddd50007227006667666666666666
777ddddd7dddddd70000000000000000000000000000000000000000eeeaaeeeccc11ccc4444444344444444324444440d55555000077000666766635c5c5c66
0111dddd07ddddd7000000000000000000000000000000000000000033aaaa3333222233555555530000000035555555006dd500005555000000000033b33b33
00111ddd007dddd70000000000000000000000000000000000000000333a3a3333828233222244450000000052222222065555500d7575d0000000053bbb5bb3
000111dd0007ddd70000000000000000000000000000000000000000bbbaabbb99922999222222440000000022222222067dd750ddd55ddd005500553bb5bb53
0000111d00007dd70000000000000000000000000000000000000000b3ba3b3b9892898922222244000000002222222206dddd50d7d57d7d055d055dbb5b5bb5
00000111000007d70000000000000000000000000000000000000000bbbaabbb9992299900000244000000002220000065555555ddd55ddd55dd55dd3b5bbb53
00000011000000770000000000000000000000000000000000000000b3ba3b3b9892898900000044000000002200000067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
00000001000000070000000000000000000000000000000000000000bbbaabbb999229990000004400000000220000006dddddd5ddd55ddddddddddd33433433
00000000000000000000000000000000000000000000000000000000bbbaabbb9992299900000044000000042200000067d7d7d5ddd55dddd7d7d7d733333333
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
000093a3a3b300000092f280b200000000ee6565656ee50002fff66fff66663302222fff22224ff20f8800088884882202622f22f2262f08411112ffff22f442
0000000000000000000000000000000000ee66565694949002f22fffff66ff6302270fff270ff2f20f880a08888488220274288f22742880442672fff2742442
0000000000a1a0a0a292f6f2b200d000000556666649494002f702f2f22ffff6022072ff2072fff200f200044448882208898f2828898ff04f26492f26492422
000000000000000000000000000000000555556655a5a5a02ff22f2ff072f2f6021c212f1c21fff202f22844888888f28f282f2f8228fff04ff222fff222f422
0000d0000092f181b293a3a3b30000005666666566ada5a02fffff2ff222f2ff02fc1f2ffc1ff8f200228888888ffff28ff8ff2f8ff8ffff4ffffffffffff424
0000000000000000000000000000000056d555656da5a5a02ffffffffffff2ff02fcff2ffcfe8f20202288888ff22002588fff22f88fffff4ffffff2fffff424
00000000d092f6f1b2000000a1a0a0a205500567557dd50002fffffffffffff302f7fffff7e8e2000222f888ff2222025ffffffffffffff54ffffffffffff424
0000000000000000000000000000000000000567777dd500002ffff2222fff6302fcf220fc8f2200022220000002222255ffffffffffff5540fffffffffff400
a1a0a0a0a293a3a3b30000009280f2b200000567777dd50000022ffffffff32300ffffffffff2200220222222222222255ffff222f2ff255400fff2222fff400
0000000000000000000000000000000000000567777dd500000002222222230300222222222222000000000000022222555fffffffff225540000ffffff00400
92f282f6b20000000000d00092c3d3b2000dddddddd0d0d0000002333333333200eeeeeeeeee8ee0000333333333333300111111111111000088888888888000
000000000000000000000000000000000ddddddddddddd0000002333333333330eeee7eeeee8e88e033333333333337301111111111111100288888888888880
d5d6e0d6c50000000000000093a3a3b3dd7ddddddddd7ddd0002333333333333ee77eeeeeee282ee073333333333373001111111111111112888888888828878
000000000000000000000000000000000dd77ddd7dddddd00006333333333333e77e22f2eee8882e337333333333333011111155555555518788881118882788
92f170f6b2000000d00000a1a0a0a200ddddd1d1d1dd1d1d002666fff3333663e7eeff82eee800fe3333733333733333111555ccccccccc58878113331888288
00000000000000000000000000000000ddd00111111d10d1002f666ffff66663eeef00822ee08008b33bfffb333bbbbb115cc1111ccc111c8881233333188828
93a3a3a3b3d0000000000092f1c6c500ddd000211210001d02fff66fff666633e7e0808028077708b3f2222fbb322f2015cc222222f22222881322fffff28882
00000000000000000000000000000000dd1100002200001102f00fffff66ff63ee20877028072708f2ff2222ffb222205c2227772ff277728222622fff262888
00000018a0a0a2a1a0a0a29271f7b20022122200f200221102fff0f2f00ffff6ee20728028877708ff2226722222762012f267172ff2717282277062f2707288
00000000000000000000000000000000f21f27100f0172102fffff2ffff0fff6e8208770ff800008ffff2702fff207202fff26772ff267722ff20c7fff0c6228
000000921982b29271f1b293a3f5b300222f2222ff2222002fffff2fffffffffe828000ff88f002e2fff2222fff2222012fff212ffff222fffff222fff222ff8
00000000000000000000000000000000112fffffffffff002fffffffffffffff0828ff222282f2e82ffffffff22fff20002ff2f2ffff2ff02ffffffff2fffff2
00d00092703bb292c371b200000000d00112fffff22fff0002fff22222f2fff308e88feeee8f82e002feeeffffffee200002f2f2ff22fff022ffffffffffff22
000000000000000000000000000000000002fffffffff200002ffeeeefffff6300e820ffffff802e002fffff22ffff2000002fffffffff00002ffffffffff222
0000003ba3a3b393a3a3b30000d0000000002fff222ff00000022ffffffff323000e2000098fff8000222ffffffff200000222ff7777f0000002ffff22ff2222
00000000000000000000000000000000000002ffffff2000000002222222230308002aafffffffaf02222222222220000022222ffffff200000002ffff202020
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
111111100000000000000567777dd500000dddddddd0d0d0000002333333333200eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
107770100000000000000567777dd5000ddddddddddddd0000002333333333330eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
170007100000000000000567777dd500dd7ddddddddd7ddd0002333333333333ee77eeeeeee222ee073333333333373001111111111111112888888888828878
100770100000000000000567777dd5000dd77ddd7dddddd00006333333333333e77e22f2eeefff2e337333333333333011111155555555518788881118882788
100700100000000000000567777dd500ddddd1d1d1dd1d1d002666fff3333663e7eefff2eeeffffe3333733333733333111555ccccccccc58878113331888288
100000100000000000000567777dd500ddd1d111111d11d1002f066fff066663eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c8881333333188828
111711100000000000000567777dd500ddd111f11f11f11d02ff006fff666633e7ef00ff2ee000feb3f2222fbb322f2015ccf222ffff222f8813222ffff28882
000000000000000000000567777dd500dd110000ff00001102f000fff000ff63ee2f070f2ef070fef2ff2222ffb222205c2f27772ff2777282226722ff262888
777777770000000000000567777dd500ff1f222ffff22f1102f070f2f070fff6ee2f070f2ef000feff2226422222462012f267172ff271728227707fff707288
777777770000000000000567777dd500ff1f27d2ff2d72102ff0002ff000f2f6ee2f000fffff0f2effff27a2fff2a7202fff26772ff267722ff20c7fff0c6228
000077700000000000000567777dd500ffff2717ff2172002ff00f2ff000f2ffee2ff0ffffff0f2e2fff2222fff2222012fff212ffff222fffff222fff222ff8
000777000000000000000567777dd50011fff222fff22f002fff0fffff0ff2ff0e2fff222222f2e02ffffffff22fff20002fffffffff2ff02ffffffff2fffff2
007770000000000000000567777dd500011ffffff22fff0002ffffffff0ffff30ee2ffeeeeeff2e002ff2fffffffff200002ffffff22fff022ffffffffffff22
077700000000000000000567777dd5000002fffffffff200002ffff22222ff6300ee20ffffff002e002ffff2222fff2000002fffffffff00002ffffffffff222
777777770000000000000567777dd50000002fff222ff00000022ffeeeeff323000e2000099fffa000222ffffffff200000222ff1222f0000002fff222ff2222
777777770000000000000567777dd500000002ffffff2000000002222222230300002aafffffffaf02222222222220000022222ffffff200000002ffff202020
__gff__
0000000000000000002121210021030300000000000000004a212121060a12090000000000000000122121210303031100000000000000000021212103030303464a5200860000000000000000000000000000000000000000002121000000210000002100000000000005050000000500000005000000000000050500000005
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000d000000000d00000000000d00000000000000000d0000000d000000000d000000000000000d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000d00000000000d00000000000d000000000000000000000000
0000000000000d000000000000000000000000000000000000000000000d000000000000000000000d00000000000d000000002f1f1f426f1f6f6f1f1f1f6f2f2f451f451f1f1f6f6f6f6f6f6f6f1d7f1d6f6f6f6f6f1f1f1f1f1f1f1f1f2f000d0000000000000000000d001a0a0a0a0a0a0a0a2a000d000d0000000d000000
00000d00000000000d00000d0000000d0000000d00000000001a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2a00000d2f1f402d2d2d2d2d2d2d2e1f2f2f1f443d3d3d3d3d3d3d3d3d3d3d3d0f3d1e2d2d2d2d2d2d2d2d2d2d2e1f2f000000000000000d00001a0a0a091f1d1f1d1f1d1f0b0a0a2a000d00000000000d
000000000d001a0a5e0a0a0a0a0a0a0a0a2a000000000d000d292f1f1f1f1f1f1f1f1f1d1f1f1f1f1f1f1f1e2f2f2f2b0d00002f6f6f426f6f6f6f6f6f3f1f2f2f453f45466f6f6f6f6f6f6f6f6f1d7f1d6f6f6f6f1f1f1f1f6f6f6f3f1f2f000000000d000000001a091f1f1f1d1f1d1f1d1f1d1f1f1f0b2a00000000000000
00000d001a0a091f7f6f6f6f6f6f6f1f1f0b2a000000000000291f2c2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2e1d2b0000002f2f6f6f6f6f6f6f6f6f3f1f2f2f1f3f6f6f6f6f1f1f1f1f6f6f6f6f7f6f6f6f1f1f1d1f1f1f1f6f6f3f1f2f0000000d0d0000001a091f6f6f6f6f6f6f6f6f6f6f6f6f6f1f0b2a000000000d00
0d00001a091f2f6f7f6f6f1f1f1f6f6f6f1f0b2a0d000d0000291f3f1f2f1f1e1f1f1f1f1f1f1f1f1f1f1f1f1f3f2f2b000d002f2f2f6f6f6f6f1f6f1d3f1e2f2f1f3f6f6f6f1f1f2f2f1f1f6f6f6f7f6f6f1f1f1f1d1f1f1f1f6f6f3f1f2f000000000000001a091f1d6f1d1f1f1d1f1d1f1d1f1f1d6f1d1f0b2a0d00000000
000d00291f402f1f7f6f1f1e1f1f1f1f6f1f1f2b00000d0000291f3f2f1f1f1f1f2f1f1f1f1f1f1f1f1f1f1f1f3f1f2b0000006d6d6d6d6d6d6d6d6e6f3f6f2f2f6f3f6f6f1f1f2f2f2f2f1d1f6f6f7f6f6f6f6f1f1f1f1f1f6f6f6f3f1f2f0000000000001a091f1d6f1d1f1f1d6f1d6f1d6f1d1f1f1d6f1d1f0b0000000d00
000d00291f3f2f6f7f1f1f1f1f1f1f1f6f6f1f0b2a00000d00291f3f1f1f1f1f1f1f2f1b192f1f2f1f2f1f1f1f3f1f2b0d000d2f2f6f6f6f6f6f6f7f6f3f6f2f2f6f3f6f6f1f1f1f2f2f461f6f6f1d7f1d6f6f6f6f6f1f1f6f6f6f6f3f1f2f000d0000001a091f6f6f1d6f6f6f6f6f6f6f6f6f6f6f6f6f1d6f6f1f0b2a000000
00000d29423f2f417f1f1f1f1f1f1f1f1f6f1f1f0b2a000000291f3f1f1f1f1f1f1f2f2b39192f1f2f1f1f1f1f3f1f2b0000002f6f1f1f1f1f6f6f7f6f3f6f2f2f6f3f6f6f6f1f1f1f1d3c3d3d3d3d0f3d3d3d3d3d3d3d3d3d3d3d3d421f2f0d0000001a091f1f1f6f6f6f6f6f466f466f466f466f6f6f6f6f1f1f1f0b2a0000
000d00296f3f2f6f7f6f1f1f2c2d2d2d2d2d2d2e1f2b0d0000291f3f1f1f1f1f1f1f2f2b0d292f1f1f1f1f1f1f3f1f2b0000002f6f1d2f1d2f1d6f7f2f3f6f2f2f6f3f6f6f6f6f1f1f1f6f6f6f6f1d7f1d6f6f6f6f6f6f6f6f1f1f423f1f2f00000000291f6f1f2c2d2d2d3d2d2d462d442d462d2d2d2d2d2d2e1f6f1f2b000d
0d000d296f3f2f417f6f6f6f3f1f1f6c6d6d6d0e6d5c000d00291f3f1f1f1f1f1f1f2f2b00292f1f1f1d1f1f1f3f1d2b0000002f1f2f1d2f1d2f1f7f6f3f6f2f2f6f3f6f6f6f1f6f6f6f1f6c6d6d6d7e6f6f1f1f1f1f1f1f6f6f1f1f3f1f2f00000000291f6f1e3f6f1f1f3f6f6f6f6f6f6f6f6f6f6f6f1f1f3f1e6f1f2b0000
000d00296f3f2f6f7f6f1f6f3f1f1f7f6f2f6f3f1d2b00000029413f411f1f1f1f1f2f2b00292f1f1f1f1f1f1f3f1f2b000d002f6f1f3f1f6f1f1d7f1f3f6f2f2f1f3f466f6f1f6f6f6f1f7f1f1f6f6f6f6f1f1f1f1f1f1f1f6f6f1f3f1f2f0000001a091f6f6f3f6f6f1f3f6f1f1f1b3a191f1f6f6f6f6f1f3f6f6f1f0b2a00
000000291f3c3d3d0f3d3d3d3e6f1f7f6f466f3f1b3b000d00292f403d3d3d421f1f2f2b0d291f443d3d3d3d3d3e2f2b0000002f6f6f3c3d3d3d3d0f3d3f6f2f2f1f3c2d2e6f1f6f6f6f1f7f6f6f6f6f6f6f1f1f1f1f1f1f1f6f6f6f3f1f2f00000d291f6f6f6f3f6f6f6f3f1d1b3a3b00393a191d6f6f6f6f3f6f6f6f1f2b00
000d00291f1f6f417f6f6f1f6f6f6f7f6f6f6f3f2b000d0000292f2f1f1f1f2f2f2f1b3b00292f1f2f461f1f1f2f2f2b0d00007d7d7d7d7d7d7d7d7e1d3f6f2f2f1f1f1f3f1d6f1f1f1f6f7f1f6f6f6f6f6f6f6f6f6f1f6f6f6f6f6f3f1f2f000000292c2d2d2d3f1f6f6f3f1f2b000d0d0d00291f6f6f6f6f3f6f6f1f1f2b00
000000393a3a3a3a5f196f6f6f6f6f7f1f443d3e2b00000000393a3a3a3a3a3a3a3a3b0d00393a3a3a3a3a3a3a3a3a3b00000d2f6f6f1f6f1f6f6f6f6f3f6f2f2f2f1f1f3c2d2e6f6f6f2f7f1f6f6f6f6f6f6f6f6f6f6f6f6f6f6f1f3f1f2f000000293f2f2f1f3f1f2f2f3f1b3b0d1a0a2a0d39196f6f6f6f3f6f6f6f1f2b0d
000d000000000d0000296f6f6f6f6f7f1f1f1f1b3b000d000d0000000d000000000000000000000000000d000d0000000000002f1f6f466f6f6f6f6f463f1f2f2f2f2f1f1f1f3f6f6f2f1d7f1d1f1f6f6f6f6f6f416f426f6f6f1f413f1f2f0d00005d0e6d6d6d0e6d6d6d0e5c000d291f2b0d00296f6f6f6f3f6f6f6f1f2b00
000000000000000000393a3a3a3a3a5f191f1b3b00000000000000000000000d00000000000d000d0000000d000000000d00002f1f443d3d3d3d3d3d3d3e1f2f2f2f2f2f2f1f3c3d3d3d3d0f3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d401f2f000000291d2f2f1f3f1f2f2f1d0b2a0d393a3b0d1a096f6f6f6f3f6f1f1f1f2b0d
0000000d0000000d000000000d000000393a3b000d000000000000000000000000000000000000000000000000000d000000002f1f1f1f6f1f1f6f1f1f1f1f2f2f2f2f2f2f1f1f1f1f2f1e7f1d1f6f6f6f6f6f6f416f421f1f1f1f1f1f1f2f000000296f6f1d1f1e1f1d6f6f1f2b000d0d0d00291f6f6f1e2d3f6f1d1f1f2b00
000000000d000000000d000000000d0000000d00000000001a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2a00000000002f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f7f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0d0000296f6f6f6f3f6f6f6f6f1f0b0a2a001a0a091f6f6f6f6f3f6f1f1f1f2b00
000d00000000000000000d000000000d000000000d00001a091f6f1f1d1d1f6f6f6f6f6f1f6f6f6f6f1f6f6f1f0b2a00000000000000000000002f2f2f2f2f2f2f2f6c6d6d6d6d6d6d6d6d7e2f2f2f2f2f2f1f1f1f1f1f1f2f00000000000000000039196f6f6f3f6f6f6f6f6f1f1f0b0a091f1f6f6f6f6f6f3f6f6f1f1b3b00
0000000000000000000000000000000000000000000000291f40426f6f1d6f6f6f6f6f6f6f6f6f6f1f6f6f6f6f1f0b2a000000000000000000002f2f2f2f1f1f1f1f7f1d2c2d2d2d2d2d2d2e2f2f2f1f1f1f6f2f2f2f1f1f2f000000000000000d0000291f6f6f3f6f6f6f6f6f6f426f406f426f6f6f6f6f6f3f6f6f1f2b000d
0000000000000000000000000000000000000000000000296f423f6f1f1f1f1f6f6f6f1f6f6f1f6f6f6f6f6f6f6f1f2b000000000000000000002f2f2f1f6f6f6f6f7f6f3f1e1f2f1f1f1d3f1f461f1f2f6f6f2f2f6f6f6f2f00000000000000000000291f6f6f3c3d3d3d3d3d3d3d1d3d1d3d3d3d3d3d3d3d3e6f1f1f2b0000
0000000000000000000000000000000000000000000000291f6f3f6f1f6c6d6d6d6d6d6d6d6d6d6d6d6d6e1f6f6f1f2b000000000000000000002f2f1f6f6f6f6f6f7f6f3f6f1f2f1f1f2f3f6f2f1f1f2f6f2f6f6f6f2f1f2f0000000000000000000d39191f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f1f1b3b0000
0000000000000000000000000000000000000000000000291f6f3f6f2f7f2f1f6f1f6f1f1f1f6f6f1f1f7f1f6f6f1f2b000000000000000000002f1f1f6f6f6f6f6f7f6f3f1d1f2f1f1f2f3f1f2f1d1f2f6f6f6f6f6f6f6f2f000000000000000000000039191f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f1f1b3b000d00
0000000000000000000000000000000000000000000000296f6f3f1f2f7f2f6f6f6f6f6f1f6f6f6f6f1f7f1f6f6f6f2b000000000000000000002f1f6f426f6f6f6f7f1d3f6f1f2f1f1f2f3f6f2f1f1f2f1d6f6f456f6f1f2f00000000000000000d00000039191f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f1f1b3b00000000
0000000000000000000000000000000000000000000000291f1f3f412f7f2f1d6f6f6f45464545456f1f7f1f1f6f6f2b000000000000000000002f1f403d3d3d3d3d0f3d3e6f2f2f1f1f2f3f1f2f1f1f2f6f6f2c2d446f1f2f0000000000000d0000000d000039191f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f1f1b3b0000000000
00000000000000000000000000000000000000000000003919413c3d3d0f3d3d3d3d3d3d3d3d3d3d3d3d0f3d3d446f2b000000000000000000002f1f6f426f6f6f6f7f1d6f6f2f2f1f1f2f3f6f2f1d1f2f1d6f3f466f6f1f2f000000000000000000000000000039191f6f6f6f6f6f6f6f6f6f6f6f6f6f1f1b3b0000000d0000
00000000000000000000000000000000000000000000000039192f2f2f7f2f1d1f6f6f45464545466f1f7f1f6f6f1d2b000000000000000000002f1f1f6f6f6f6f6f7f6f6f6f2f2f1f1f2f3f1f2f1f1f2f6f6f3f6f1f2f2f2f000000000000000000000d0000000039191d1d1d6f6f1d6f1d6f6f1d1d1d1b3b00000000000000
00000000000000000000000000000000000000000000000000393a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3b000000000000000000002f2f1f6f6f6f6f6f7f6f6f2f2f2f1f1f2f3f1e2f1f1f2f1d6f3f1f2f2f2f2f00000000000000000000000000000000393a3a191d1f1f1d1f1f1d1b3a3a3b0000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f2f2f1f6f6f6f6f7f6f2f2f1d2f1f1f1f3c3d3d3d3d3d3d3d3e1f2f2f2f2f00000000000000000000000000000d00000d00393a3a3a3a3a3a3a3b0000000d00000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f2f2f2f2f1f1f1f7f2f2f1d1d2f2f1f1f1f1f1f1f6f6f6f1f1f2f2f2f2f2f0000000000000000000000000000000000000000000d00000000000d0000000000000000000000
000000000d0000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f2f2f2f2f2f2f2f7f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f000000000000000000000000000000000000000000000d0000000d000000000000000000000000
__sfx__
0002000013510215102d5103a5103f5103f5103d5103750032500335002e500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000300002865025650216401e6401664011640096300063000630006300000020600266001e600006001260009600066000060000600006000060000600006000060000600006000060000600006000060000600
000100001905032050240500d05003050070500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001b340243402934030340333403734037340333402e3402b3402b3402b3402b3402e3402e340303403034033340333403334033340333403334033340393003d300343002a30024300253002e30031300
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00000c0500c0500e0500e05011050110500e0500e05015050150500e0500e05011050110500e0500e0500c0500c0500e0500e05011050110500e0500e05015050150500e0500e05011050110500e0500e050
