PICOWARS DEV NOTES
==================

regex to replace comments: \/\*[\s\S]*?\*\/|([^:]|^)\-\-.*$

The below are notes for my use during development. 

-- sfx
-- sfx_selector_move = 0
-- sfx_unit_rest = 1
-- sfx_select_unit = 2
-- sfx_undefined_error = 3
-- sfx_cant_move_there = 4
-- sfx_cancel_movement = 5
-- sfx_prompt_change = 6
-- sfx_end_turn = 7
-- sfx_unit_death = 8
-- sfx_capturing = 9
-- sfx_captured = 10
-- sfx_build_unit = 11

-- tile flags
-- flag_terrain = 0  -- required for terrain
-- flag_road = 1
-- flag_river = 2
-- flag_forest = 3
-- flag_mountain = 4
-- flag_cliff = 5
-- flag_plain = 6

-- flag_structure = 1  -- required for structure
-- flag_capital = 2
-- flag_city = 3
-- flag_base = 4

-- flag_player_1_owner = 6
-- flag_player_2_owner = 7

-- mobility ids
-- mobility_infantry = 0
-- mobility_mech = 1
-- mobility_tires = 2
-- mobility_treads = 3

-- map currently loaded
-- current_map = nil

-- coroutines
-- active_attack_coroutine = nil
-- active_ai_coroutine = nil
-- active_end_turn_coroutine = nil
-- currently_attacking = false
-- attack_coroutine_u1 = nil
-- attack_coroutine_u2 = nil




-- selector variables
  -- selector_selecting = false

  -- selection types are:
  -- unit selection: 0
  -- unit movement: 1
  -- unit order prompt: 2
  -- unit attack prompt: 3
  -- menu prompt for ending turn: 4
  -- unit attack range selection: 5
  -- enemy unit movement range selection: 6
  -- unit actively attacking: 7
  -- constructing unit: 8
  -- unloading units(from APC): 9

  -- selector_selection_type = nil

  -- currently selected object
  -- selector_selection = nil


  -- during a prompt, prompt_options will be populated with options
  -- for unit prompt:
  -- 1 = rest
  -- 2 = attack
  -- 3 = capture
  -- for attack prompt:
  --   each index is an index into selector_attack_targets
  -- for menu prompt:
  -- 1 = end turn


-- Music making notes
  -- 1: pitch slide at beginning of note. keep this effect between notes that are close to each other. (A and B, NOT B and C)
  -- 2: vibrato at the end of a note to give it some wave before the next note
  -- 3: