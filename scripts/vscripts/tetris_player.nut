::PlayerSpawned <- [];
::GlobalTickCounter <- 0;

OnGameEvent("player_spawn", function(params)
{
    local player = GetPlayerFromUserID(params.userid);

    if (params.team == 0)
    {
        SendGlobalGameEvent("player_activate", {userid = params.userid});
        for (local i = 0; i < 6; i++)
        {
            player.SendGameText(-1, -1, i, "255 255 255", " ");
        }
    }

    player.ValidateScriptScope();

    CookieUtil.CreateCache(player);

    player.AddHudHideFlags(HIDEHUD_HEALTH | HIDEHUD_MISCSTATUS | HIDEHUD_WEAPONSELECTION | HIDEHUD_FLASHLIGHT | HIDEHUD_CROSSHAIR);
    player.RemoveAllWeapons();
    player.RemoveAllWearables();
    player.RemoveAllViewmodels();

    player.AddFlag(FL_ATCONTROLS);
    player.DisableDraw();
    player.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT);
    SetPropInt(player, "m_iFOV", 75);

    if(PlayerSpawned.find(player) != null)
        return;

    PlayerSpawned.append(player);

    player.InitPlayerVariables();

    player.SwitchTeam(TF_TEAM_RED);
    SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SCOUT);
    player.ForceRespawn();

    RunWithDelay(0.1, function()
    {
        player.AddCustomAttribute("voice pitch scale", 0, -1);
    })
})

OnGameEvent("player_disconnect", 0, function(params)
{
    local player = GetPlayerFromUserID(params.userid);
    player.RemoveInstancedProps();
})

::CTFPlayer.InitPlayerVariables <- function()
{
    SetVar("gamemode", null);

    SetVar("menu_index", MENU.MainMenu);
    SetVar("selected_option", 0);
    GenerateMenuText();

    SetVar("last_buttons", 0);

    ResetTetrisVariables();
}

::CTFPlayer.ResetTetrisVariables <- function()
{
    SetVar("score", 0);
    SetVar("lines_cleared", 0);
    SetVar("level", 0);

    SetVar("next_gravity_ticks", 0);
    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);

    SetVar("das_ticks", -DAS_INITIAL_TICKS);
    SetVar("das_direction", null);

    SetVar("last_tetromino_action", null);
    SetVar("back_to_back_combo", 0);
    SetVar("last_major_action", null);
    SetVar("back_to_back_full_clear", 0);
    SetVar("last_full_clear", null);
    SetVar("major_action_display_ticks", 0);

    SetVar("line_clear_delay_ticks", 0);
    SetVar("line_clear_flash_ticks", 0);
    SetVar("lines_to_clear", []);

    SetVar("board_blocks", ConstructTwoDimArray(BOARD_SIZE.x + 1, BOARD_SIZE.y, null));
    SetVar("active_tetromino", null);
    SetVar("ghost_tetromino", null);

    SetVar("can_switch_hold", true);
    SetVar("hold_tetromino_shape", null);
    SetVar("hold_tetromino_cluster_model", null);

    SetVar("grab_bag", []);
    SetVar("next_tetromino_model_array", array(NEXT_TETROMINO_COUNT, null));
}

AddListener("tick_frame", 0, function()
{
    GlobalTickCounter += 1;
    foreach(player in GetAlivePlayers())
    {
        SetPropInt(player, "m_Shared.m_nPlayerState", 2); //stops suicide commands
        player.OnTick();
        player.SetVar("last_buttons", player.GetButtons());
    }
});

::CTFPlayer.OnTick <- function()
{
    if(DEBUG)
        DrawDebugVars();

    HandleMenuCosmetics();
    //if we are in a menu, we aren't playing the game
    if(GetVar("menu_index") != null)
    {
        HandleCurrentMenu();
        return;
    }

    //tick regular tetris from here
    if(GetVar("gamemode") == null)
        return;

    UpdateHUD();
    GetVar("gamemode").OnTick();
    CheckButtonCommands();

    if(!GetVar("active_tetromino"))
        return;

    if(HandleLineClearDelay())
        return;

    HandleTetrominoLock();
    HandleTetrominoGravity();
}

::CTFPlayer.HandleMenuCosmetics <- function()
{
    local menu_index = GetVar("menu_index");
    local ingame = menu_index != null && menu_index != MENU.Pause && menu_index != MENU.GameOver;

    SetScriptOverlayMaterial(menu_index != null ? "vgui/menu_select.vmt" : null);
    SetPropVector(this, "m_Local.m_skybox3d.origin", SKY_POS + (ingame ? MENU_SKY_OFFSET : Vector(0,0,0)));

    local desired_viewcontrol = FindByName(null, ingame ? "point_viewcontrol2" : "point_viewcontrol");
    if(GetPropEntity(this, "m_hViewEntity") != desired_viewcontrol)
        desired_viewcontrol.AcceptInput("enable", "", this, this);
}

::CTFPlayer.UpdateHUD <- function()
{
    SendGameText(-0.676, -0.85, CHAN_HOLD, (GetVar("can_switch_hold") ? "255 255 255" : "60 60 60"), "HOLD");
    SendGameText(0.676, -0.85, CHAN_NEXT, "255 255 255", "NEXT");
    HandleDisplayMajorAction();
    GetVar("gamemode").UpdateHUD();
}

::CTFPlayer.HandleDisplayMajorAction <- function()
{
    if(GetVar("major_action_display_ticks") <= 0)
    {
        SendGameText(-1, -0.025, CHAN_MAJOR_ACTION, "255 255 255", "");
        return;
    }

    SubtractVar("major_action_display_ticks", 1);

    local major_action_string = "";

    switch(GetVar("last_major_action"))
    {
        case MAJOR_ACTION.SINGLE: major_action_string += "SINGLE"; break;
        case MAJOR_ACTION.DOUBLE: major_action_string += "DOUBLE"; break;
        case MAJOR_ACTION.TRIPLE: major_action_string += "TRIPLE"; break;
        case MAJOR_ACTION.TETRIS: major_action_string += "TETRIS"; break;
        case MAJOR_ACTION.MINI_TSPIN: major_action_string += "MINI T-SPIN"; break;
        case MAJOR_ACTION.TSPIN: major_action_string += "T-SPIN"; break;
        case MAJOR_ACTION.MINI_TSPIN_SINGLE: major_action_string += "MINI T-SPIN SINGLE"; break;
        case MAJOR_ACTION.TSPIN_SINGLE: major_action_string += "T-SPIN SINGLE"; break;
        case MAJOR_ACTION.TSPIN_DOUBLE: major_action_string += "T-SPIN DOUBLE"; break;
        case MAJOR_ACTION.TSPIN_TRIPLE: major_action_string += "T-SPIN TRIPLE"; break;
    }

    local back_to_back_string = "";

    if(GetVar("back_to_back_combo") > 1)
    {
        local combo_streak = (GetVar("back_to_back_combo") > 2) ? ("x" + (GetVar("back_to_back_combo") - 1) + " ") : "";
        back_to_back_string = "BACK-TO-BACK " + combo_streak
    }

    local full_clear_string = "";
    if(GetVar("last_full_clear") != null)
    {
        full_clear_string += "\n ";
        switch(GetVar("last_full_clear"))
        {
            case PERFECT_CLEAR.SINGLE: full_clear_string += "SINGLE-LINE PERFECT CLEAR"; break;
            case PERFECT_CLEAR.DOUBLE: full_clear_string += "DOUBLE-LINE PERFECT CLEAR"; break;
            case PERFECT_CLEAR.TRIPLE: full_clear_string += "TRIPLE-LINE PERFECT CLEAR"; break;
            case PERFECT_CLEAR.TETRIS: full_clear_string += "TETRIS PERFECT CLEAR"; break;
            case PERFECT_CLEAR.BACK_TO_BACK_TETRIS: full_clear_string += "BACK-TO-BACK TETIRS PERFECT CLEAR"; break;
        }
    }

    local color = remapclamped(GetVar("major_action_display_ticks"), (MAJOR_ACTION_DISPLAY_TICKS - MAJOR_ACTION_DISPLAY_TICKS/4.0), 0.0, 255, 0).tostring();

    local y = GetVar("last_full_clear") != null ? -0.001 : -0.025

    SendGameText(-1, y, CHAN_MAJOR_ACTION, color + " " + color + " " + color, back_to_back_string + major_action_string + full_clear_string);
}

::CTFPlayer.HandleLineClearDelay <- function()
{
    if(!(GetVar("line_clear_delay_ticks") > 0))
        return false;

    if(GetVar("line_clear_delay_ticks") == 1)
    {
        ClearLines(GetVar("lines_to_clear"));
        CreateNewActiveTetromino(CycleGrabbag(), true);
        SetVar("line_clear_delay_ticks", 0);
        SetVar("lines_to_clear", []);
        return true;
    }

    // handle flashing
    if((GetVar("line_clear_flash_ticks") % (LINE_CLEAR_FLASH_INTERVAL * 2)) == 0)
    {
        foreach(y in GetVar("lines_to_clear"))
        {
            foreach(block in GetBlocksAtY(y))
            {
                block.SetColorCustom([50,50,50,255]);
            }
        }
    }
    else if((GetVar("line_clear_flash_ticks") % LINE_CLEAR_FLASH_INTERVAL) == 0)
    {
        foreach(y in GetVar("lines_to_clear"))
        {
            foreach(block in GetBlocksAtY(y))
            {
                block.SetColorCustom([150,150,150,255]);
            }
        }
    }

    AddVar("line_clear_flash_ticks", 1)
    SubtractVar("line_clear_delay_ticks", 1);
    return true;
}

::CTFPlayer.HandleTetrominoLock <- function()
{
    local tetromino = GetVar("active_tetromino");

    // we've reached the lock reset limit, land as soon as we can
    if(GetVar("lock_resets") >= LOCK_DELAY_RESET_LIMIT && tetromino.DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
    {
        tetromino.Land();
        return;
    }

    // Are we currently amist locking the tetromino? If not, check if we should by seeing if we can move down again
    if(GetVar("lock_time_ticks") == 0 && tetromino.DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
    {
        SetVar("lock_time_ticks", LOCK_DELAY_TICKS);
        PlaySoundForPlayer({sound_name = "tetromino_startlock.mp3", volume = 0.75, pitch = remapclamped(GetVar("lock_resets"), 0.0, 14, 100, 200)});
    }

    if(GetVar("lock_time_ticks") > 0)
    {
        if(!tetromino.DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
        {
            SetVar("lock_time_ticks", 0);
            tetromino.ColorBlocks(1);
            AddVar("lock_resets", 1);
            return;
        }

        local percent = remapclamped(GetVar("lock_time_ticks").tofloat(), LOCK_DELAY_TICKS, 0, 1, 0.25);
        tetromino.ColorBlocks(percent);

        SubtractVar("lock_time_ticks", 1);

        if(GetVar("lock_time_ticks") == 0)
        {
            tetromino.Land();
            return;
        }
    }
    else
        tetromino.ColorBlocks(1);
}

::CTFPlayer.HandleTetrominoGravity <- function()
{
    local soft_drop_active = IsHoldingButton(IN_BACK);

    if(GetVar("next_gravity_ticks") <= 0 || (soft_drop_active && (GetNextGravityTimeFromLevel() - GetVar("next_gravity_ticks")) >= 2))
    {
        SetVar("next_gravity_ticks", GetNextGravityTimeFromLevel());

        if(soft_drop_active && !GetVar("active_tetromino").DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
        {
            AddVar("score", 1);
            PlaySoundForPlayer({sound_name = "tetromino_softdrop.mp3", volume = 0.5});
        }

        GetVar("active_tetromino").Move(MOVE_DIR.DOWN);
    }
    else
        SubtractVar("next_gravity_ticks", 1);
}

::CTFPlayer.OnTetrominoLand <- function()
{
    local t_spin = false;
    // lets check for a t-spin
    // if we just landed a T and our last move was a rotation
    // AND atleast three adjacent tiles to the center are either a block or out of bounds
    // we have a t-spin to award
    local last_action = GetVar("last_tetromino_action");
    if(GetVar("active_tetromino").shape == "T")
    {
        if(last_action == TETROMINO_ACTION.ROTATION || last_action == TETROMINO_ACTION.ROTATION_WALLKICK)
        {
            local center_pos = GetVar("active_tetromino").blocks[0].pos;
            local check_offset = [Vector2D(1, 1), Vector2D(1, -1), Vector2D(-1, 1), Vector2D(-1, -1)];
            local occupied_slots = 0;

            for (local i = 0; i < 4; i++)
            {
                local offset = center_pos + check_offset[i];

                // position is out of bounds, this is occupied
                if(offset.x >= BOARD_SIZE.x || offset.x < 0 || offset.y >= BOARD_SIZE.y)
                {
                    occupied_slots += 1;
                    continue;
                }
                if(GetVar("board_blocks")[offset.x][offset.y])
                {
                    occupied_slots += 1;
                    continue;
                }
            }

            if(occupied_slots >= 3)
            {
                t_spin = true;
            }
        }
    }

    // clear full lines
    local lines_cleared_pre = GetVar("lines_cleared");
    local lines_cleared = MarkFullLinesForClearing();

    local major_action = null;

    local increment_level = false;

    // a mini-tspin is when a rotation wallkick is the last action AND we didn't clear more than one line
    local mini_tspin = (last_action == TETROMINO_ACTION.ROTATION_WALLKICK && lines_cleared >= 1);

    // did we perform a major action that awards points
    if(t_spin && lines_cleared == 0)
        major_action = (mini_tspin ? MAJOR_ACTION.MINI_TSPIN : MAJOR_ACTION.TSPIN);
    else if(lines_cleared > 0)
    {
        if(t_spin)
        {
            switch(lines_cleared)
            {
                case 1: major_action = (mini_tspin ? MAJOR_ACTION.MINI_TSPIN_SINGLE : MAJOR_ACTION.TSPIN_SINGLE); break;
                case 2: major_action = MAJOR_ACTION.TSPIN_DOUBLE; break;
                case 3: major_action = MAJOR_ACTION.TSPIN_TRIPLE; break;
            }
            AddVar("back_to_back_combo", 1);
        }
        else
        {
            switch(lines_cleared)
            {
                case 1: major_action = MAJOR_ACTION.SINGLE; break;
                case 2: major_action = MAJOR_ACTION.DOUBLE; break;
                case 3: major_action = MAJOR_ACTION.TRIPLE; break;
                case 4: major_action = MAJOR_ACTION.TETRIS; break;
            }
            if(major_action == MAJOR_ACTION.TETRIS)
                AddVar("back_to_back_combo", 1);
            else
                SetVar("back_to_back_combo", 0);
        }

        // Check if we should go up a level
        AddVar("lines_cleared", lines_cleared);
        if(floor(lines_cleared_pre / 10) < floor(GetVar("lines_cleared") / 10) && GetVar("gamemode").allow_increment_level)
            increment_level = true;
    }

    //check for perfect clears
    local perfect_clear_action = null;
    if(IsBoardEmpty())
    {
        switch(lines_cleared)
        {
            case 1: perfect_clear_action = PERFECT_CLEAR.SINGLE; break;
            case 2: perfect_clear_action = PERFECT_CLEAR.DOUBLE; break;
            case 3: perfect_clear_action = PERFECT_CLEAR.TRIPLE; break;
            case 4:
            {
                if(GetVar("back_to_back_combo") > 0)
                    perfect_clear_action = PERFECT_CLEAR.BACK_TO_BACK_TETRIS;
                else
                    perfect_clear_action = PERFECT_CLEAR.TETRIS;

                break;
            }
        }

        SetVar("last_full_clear", perfect_clear_action);

        if(perfect_clear_action >= PERFECT_CLEAR.TETRIS)
            AddVar("back_to_back_full_clear", 1);
        else
            SetVar("back_to_back_full_clear", 0);
    }
    else
    {
        SetVar("back_to_back_full_clear", 0);
        SetVar("last_full_clear", null);
    }

    // if we performed a major action, show it off and award points
    if(major_action != null)
    {
        PlayMajorActionSound(major_action, increment_level);
        SetVar("last_major_action", major_action);
        SetVar("major_action_display_ticks", MAJOR_ACTION_DISPLAY_TICKS + (GetVar("last_full_clear") ? MAJOR_ACTION_DISPLAY_TICKS_PERFECT_CLEAR : 0));

        local full_clear_score = 0;
        if(perfect_clear_action)
            full_clear_score = PERFECT_CLEAR_SCORE[perfect_clear_action];

        AddVar("score", (MAJOR_ACTION_SCORE[major_action] + full_clear_score) * (GetVar("level") + 1) * (GetVar("back_to_back_combo") > 1 ? BACK_TO_BACK_SCORE_MULT : 1));
    }

    if(increment_level)
        AddVar("level", 1);

    if(lines_cleared == 0)
        CreateNewActiveTetromino(CycleGrabbag(), true);

    PlaySoundForPlayer({sound_name = "tetromino_land.mp3", volume = 0.75});

    GetVar("gamemode").OnTetrominoLand(lines_cleared);
}

::CTFPlayer.DoGameOver <- function(victory)
{
    GetVar("gamemode").OnGameOver(victory);

    SetVar("menu_index", MENU.GameOver);
    SetVar("selected_option", 0);

    PlaySoundForPlayer({sound_name = "tetris_gameover.mp3"});

    for(local y = 0; y < BOARD_SIZE.y; y++)
    {
        for(local x = 1; x < BOARD_SIZE.x + 1; x++)
        {
            if(GetVar("board_blocks")[x][y])
                GetVar("board_blocks")[x][y].SetColorCustom([50, 50, 50, 255]);
        }
    }
}

::CTFPlayer.OnGrabBagUpdated <- function(removed_tetromino)
{
    foreach(i, tetromino_model in GetVar("next_tetromino_model_array"))
    {
        local grab_bag_shape = GetVar("grab_bag")[i];

        if(!tetromino_model)
        {
            GetVar("next_tetromino_model_array")[i] = CreateInstancedProp("models/empty.mdl");
            local z_offset = (i * NEXT_TETROMINO_OFFSET) + (i != 0 ? NEXT_TETROMINO_INITIAL_OFFSET : 0);
            GetVar("next_tetromino_model_array")[i].SetOrigin(NEXT_TETROMINO_POS + Vector(0,0,z_offset));

            if(i != 0)
                GetVar("next_tetromino_model_array")[i].SetModelScale(0.75, 0)

            SetPropInt(GetVar("next_tetromino_model_array")[i], "m_nRenderMode", kRenderTransColor);
        }

        GetVar("next_tetromino_model_array")[i].SetModel(GetClusterModelFromShape(grab_bag_shape));
        SetEntityColor(GetVar("next_tetromino_model_array")[i], TETROMINO_COLORS[grab_bag_shape]);
    }
}

::CTFPlayer.CheckButtonCommands <- function()
{
    if(WasButtonJustPressed(IN_RELOAD))
    {
        GetVar("gamemode").OnRoundReset();
    }

    if(WasButtonJustPressed(IN_SCORE))
    {
        SetVar("menu_index", MENU.Pause);
        SetVar("selected_option", 0);
    }

    if(GetVar("line_clear_delay_ticks") > 0)
        return;

    local tetromino = GetVar("active_tetromino");

    if(!tetromino)
        return;

    // handle delayed auto shift
    if(IsHoldingButton(IN_MOVELEFT))
    {
        if(GetVar("das_direction") != MOVE_DIR.LEFT)
        {
            SetVar("das_ticks", -DAS_INITIAL_TICKS);
            SetVar("das_direction", MOVE_DIR.LEFT);
            if(tetromino.Move(MOVE_DIR.LEFT))
                PlaySoundForPlayer({sound_name = "tetromino_move.mp3", volume = 0.35});
        }
        else
            AddVar("das_ticks", 1);
    }
    else if(IsHoldingButton(IN_MOVERIGHT))
    {
        if(GetVar("das_direction") != MOVE_DIR.RIGHT)
        {
            SetVar("das_ticks", -DAS_INITIAL_TICKS);
            SetVar("das_direction", MOVE_DIR.RIGHT);
            if(tetromino.Move(MOVE_DIR.RIGHT))
                PlaySoundForPlayer({sound_name = "tetromino_move.mp3", volume = 0.35});
        }
        else
            AddVar("das_ticks", 1);
    }
    else
    {
        SetVar("das_direction", null);
    }

    if(GetVar("das_direction") && GetVar("das_ticks") > 0 && GetVar("das_ticks") % DAS_PERIOD_TICKS == 0)
    {
        if(tetromino.Move(GetVar("das_direction")))
            PlaySoundForPlayer({sound_name = "tetromino_move.mp3", volume = 0.35});
    }

    if(WasButtonJustPressed(IN_ATTACK))
    {
        tetromino.Rotate(false);
        PlaySoundForPlayer({sound_name = "tetromino_rotate.mp3", volume = 0.75});
    }
    if(WasButtonJustPressed(IN_ATTACK2))
    {
        tetromino.Rotate(true);
        PlaySoundForPlayer({sound_name = "tetromino_rotate.mp3", volume = 0.75});
    }

    if(WasButtonJustPressed(IN_BACK))
    {
        if(GetVar("active_tetromino").DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
            tetromino.Land();
    }
    if(WasButtonJustPressed(IN_FORWARD))
        SwitchHoldTetromino();
    if(WasButtonJustPressed(IN_JUMP))
    {
        local times_moved = GetVar("active_tetromino").SnapToFloor();
        AddVar("score", 2 * times_moved);

        if(times_moved > 0)
            SetVar("last_tetromino_action", TETROMINO_ACTION.MOVEMENT)

        tetromino.Land();
        PlaySoundForPlayer({sound_name = "tetromino_harddrop.mp3", volume = 0.75});
    }
}

::CTFPlayer.SwitchHoldTetromino <- function()
{
    if(!GetVar("can_switch_hold"))
        return;

    local current_shape = GetVar("active_tetromino").shape;
    GetVar("active_tetromino").Destroy();

    // if we have a shape in hold, create a new active tetromino with it
    // if we don't, create a new active tetromino from grabbag
    if(GetVar("hold_tetromino_shape"))
        CreateNewActiveTetromino(GetVar("hold_tetromino_shape"), false);
    else
        CreateNewActiveTetromino(CycleGrabbag(), false);

    SetVar("hold_tetromino_shape", current_shape);

    if(!GetVar("hold_tetromino_cluster_model"))
    {
        SetVar("hold_tetromino_cluster_model", CreateInstancedProp(GetClusterModelFromShape(current_shape)));
        local held_tetromino_ent = GetVar("hold_tetromino_cluster_model");
        held_tetromino_ent.SetOrigin(HELD_TETROMINO_POS);
        SetPropInt(held_tetromino_ent, "m_nRenderMode", kRenderTransColor);
    }
    else
        GetVar("hold_tetromino_cluster_model").SetModel(GetClusterModelFromShape(current_shape));

    SetEntityColor(GetVar("hold_tetromino_cluster_model"), TETROMINO_COLORS[current_shape]);
    PlaySoundForPlayer({sound_name = "tetromino_hold.mp3", volume = 0.75});
}

::CTFPlayer.CreateNewActiveTetromino <- function(shape, new_hold_state)
{
    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);
    SetVar("active_tetromino", Tetromino(this, shape, TETROMINO_TYPE.ACTIVE));
    SetVar("can_switch_hold", new_hold_state);
    SetVar("next_gravity_ticks", GetNextGravityTimeFromLevel());
    UpdateGhostTetromino();
}

::CTFPlayer.UpdateGhostTetromino <- function()
{
    local active_tetromino = GetVar("active_tetromino");
    if(!active_tetromino)
        return;

    if(!GetVar("ghost_tetromino"))
        SetVar("ghost_tetromino", Tetromino(this, active_tetromino.shape, TETROMINO_TYPE.GHOST));

    local ghost_tetromino = GetVar("ghost_tetromino");

    ghost_tetromino.shape = active_tetromino.shape;
    ghost_tetromino.ColorBlocks(1);
    ghost_tetromino.SetBlockPos(active_tetromino.GetGhostBlockPos(), GetMoveDir(MOVE_DIR.UP));
}