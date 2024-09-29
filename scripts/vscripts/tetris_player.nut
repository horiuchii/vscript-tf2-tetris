::PlayerLastSpawn <- {};
::GlobalTickCounter <- 0;

OnGameEvent("player_spawn", 0, function(params)
{
    local player = GetPlayerFromUserID(params.userid);

    player.ValidateScriptScope();

    if(player in PlayerLastSpawn)
    {
        if(!(PlayerLastSpawn[player] > Time() + 0.15))
            return;
    }

    PlayerLastSpawn[player] <- Time();

    player.InitPlayerVariables();

    player.SwitchTeam(TF_TEAM_RED);
    SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SCOUT);
    player.ForceRespawn();

    player.RemoveAllWeapons();
    player.RemoveAllWearables();

    player.AddFlag(FL_ATCONTROLS);
    player.DisableDraw();
    player.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT);
    SetPropInt(player, "m_iFOV", 75);

    RunWithDelay(0.1, function()
    {
        player.AddCustomAttribute("voice pitch scale", 0, -1);
        player.AddHudHideFlags(HIDEHUD_HEALTH | HIDEHUD_MISCSTATUS | HIDEHUD_WEAPONSELECTION | HIDEHUD_FLASHLIGHT | HIDEHUD_CROSSHAIR);
    })

    FindByName(null, "point_viewcontrol").AcceptInput("enable", "", player, player);
})

OnGameEvent("player_disconnect", 0, function(params)
{
    local player = GetPlayerFromUserID(params.userid);
    player.RemoveInstancedProps();
})

::CTFPlayer.InitPlayerVariables <- function()
{
    SetVar("last_buttons", 0);

    SetVar("next_gravity_ticks", 0);
    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);

    SetVar("score", 0);
    SetVar("lines_cleared", 0);
    SetVar("level", 0);

    SetVar("last_tetromino_action", null);
    SetVar("last_line_clear_difficult", false);

    SetVar("last_major_action", null);
    SetVar("backtoback_display", false);
    SetVar("major_action_display_ticks", 0);

    SetVar("game_active", false);
    SetVar("game_paused", false);

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
    }
});

::CTFPlayer.OnTick <- function()
{
    CheckButtonCommands();
    SetVar("last_buttons", GetButtons());

    UpdateHUD();

    if(GetVar("game_paused") || !GetVar("game_active") || !GetVar("active_tetromino"))
        return;

    HandleTetrominoLock();

    HandleTetrominoGravity();
}

::CTFPlayer.UpdateHUD <- function()
{
    SendGameText(-0.676, -0.85, 0, GetVar("can_switch_hold") ? "255 255 255" : "60 60 60", "HOLD");
    SendGameText(-0.666, -0.375, 1, "255 255 255", "HISCORE\n" + 0 + "\n\nSCORE\n" + GetVar("score") + "\n\nLINES\n" + GetVar("lines_cleared") + "\n\nLEVEL\n" + (GetVar("level") + 1));
    SendGameText(0.676, -0.85, 2, "255 255 255", "NEXT");

    if(GetVar("major_action_display_ticks") > 0)
    {
        SubtractVar("major_action_display_ticks", 1);

        local major_action_string = "";
        switch(GetVar("last_major_action"))
        {
            case MAJOR_ACTION.SINGLE: major_action_string = "SINGLE"; break;
            case MAJOR_ACTION.DOUBLE: major_action_string = "DOUBLE"; break;
            case MAJOR_ACTION.TRIPLE: major_action_string = "TRIPLE"; break;
            case MAJOR_ACTION.TETRIS: major_action_string = "TETRIS"; break;
            case MAJOR_ACTION.TSPIN: major_action_string = "T-SPIN"; break;
            case MAJOR_ACTION.TSPIN_SINGLE: major_action_string = "T-SPIN SINGLE"; break;
            case MAJOR_ACTION.TSPIN_DOUBLE: major_action_string = "T-SPIN DOUBLE"; break;
            case MAJOR_ACTION.TSPIN_TRIPLE: major_action_string = "T-SPIN TRIPLE"; break;
        }

        SendGameText(-0.666, -0.275, 3, "255 255 255", (GetVar("backtoback_display") ? "BACK-TO-BACK " : "") + major_action_string);
    }
    else
        SendGameText(-0.666, -0.275, 3, "255 255 255", "");

    if(GetVar("game_paused"))
        SendGameText(-1, -1, 4, "255 255 255", "PAUSED\nPRESS [SCOREBOARD] TO UNPAUSE");
    else if(!GetVar("game_active"))
        SendGameText(-1, -1, 4, "255 255 255", "GAME OVER\nPRESS [SCOREBOARD] TO PLAY AGAIN");
    else
        SendGameText(-1, -1, 4, "255 255 255", "");

    local debug_print = DebugGetAllVars();
    if(debug_print.len() > 220)
        SendGameText(0.666, -0.150, 5, "255 255 255", debug_print.slice(0, 220));
    else
        SendGameText(0.666, -0.150, 5, "255 255 255", debug_print);
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
        SetVar("lock_time_ticks", LOCK_DELAY_TICKS);

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
    // Handle gravity on our active tetromino
    if(GetVar("next_gravity_ticks") <= 0)
    {
        local soft_drop_active = IsHoldingButton(IN_BACK);
        SetVar("next_gravity_ticks", soft_drop_active ? floor(GetNextGravityTimeFromLevel()/10) : GetNextGravityTimeFromLevel());

        if(soft_drop_active && !GetVar("active_tetromino").DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
            AddVar("score", 1);

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
    if(GetVar("active_tetromino").shape == "T")
    {
        local last_action = GetVar("last_tetromino_action");
        if(last_action == TETROMINO_ACTION.ROTATION || last_action == TETROMINO_ACTION.ROTATION_WALLKICK)
        {
            local center_pos = GetVar("active_tetromino").blocks[0].pos;
            local check_offset = [Vector2D(1, 1), Vector2D(1, -1), Vector2D(-1, 1), Vector2D(-1, -1)];
            local occupied_slots = 0;

            for (local i = 0; i < 4; i++)
            {
                local offset = center_pos + check_offset[i];

                // position is out of bounds, this is occupied
                if(offset.x > BOARD_SIZE.x || offset.x < 0 || offset.y > BOARD_SIZE.y)
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
    local lines_cleared = ClearFullLines();

    local last_line_clear_was_difficult = GetVar("last_line_clear_difficult");
    local major_action = null;

    local increment_level = false;

    // did we perform a major action that awards points
    if(t_spin && lines_cleared == 0)
        major_action = MAJOR_ACTION.TSPIN;
    else if(lines_cleared > 0)
    {
        if(t_spin)
        {
            switch(lines_cleared)
            {
                case 1: major_action = MAJOR_ACTION.TSPIN_SINGLE; break;
                case 2: major_action = MAJOR_ACTION.TSPIN_DOUBLE; break;
                case 3: major_action = MAJOR_ACTION.TSPIN_TRIPLE; break;
            }
            SetVar("last_line_clear_difficult", true);
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
            SetVar("last_line_clear_difficult", major_action == MAJOR_ACTION.TETRIS);
        }

        // Check if we should go up a level
        AddVar("lines_cleared", lines_cleared);
        if(floor(lines_cleared_pre / 10) < floor(GetVar("lines_cleared") / 10))
            increment_level = true;
    }

    // if we performed a major action, show it off and award points
    if(major_action != null)
    {
        local back_to_back = last_line_clear_was_difficult && GetVar("last_line_clear_difficult");

        SetVar("last_major_action", major_action);
        SetVar("backtoback_display", back_to_back);
        SetVar("major_action_display_ticks", MAJOR_ACTION_DISPLAY_TICKS);

        AddVar("score", MAJOR_ACTION_SCORE[major_action] * (GetVar("level") + 1) * (back_to_back ? BACK_TO_BACK_SCORE_MULT : 1));
    }

    if(increment_level)
        AddVar("level", 1);

    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);
    SetVar("active_tetromino", Tetromino(this, CycleGrabbag(), TETROMINO_TYPE.ACTIVE));
    SetVar("can_switch_hold", true);
    SetVar("next_gravity_ticks", GetNextGravityTimeFromLevel());
    UpdateGhostTetromino();
}

::CTFPlayer.OnGrabBagUpdated <- function(removed_tetromino)
{
    foreach(i, tetromino_model in GetVar("next_tetromino_model_array"))
    {
        local grab_bag_shape = GetVar("grab_bag")[i];

        if(!tetromino_model)
        {
            GetVar("next_tetromino_model_array")[i] = CreateInstancedProp(this, "models/empty.mdl");
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
    if(WasButtonJustPressed(IN_SCORE))
    {
        if(GetVar("game_active"))
            SetVar("game_paused", !GetVar("game_paused"));
        else
        {
            ResetEverything();
            return;
        }
    }

    if(!GetVar("game_active") || GetVar("game_paused"))
        return;

    local tetromino = GetVar("active_tetromino");

    if(!tetromino)
        return;

    if(WasButtonJustPressed(IN_MOVELEFT))
        tetromino.Move(MOVE_DIR.LEFT);
    if(WasButtonJustPressed(IN_MOVERIGHT))
        tetromino.Move(MOVE_DIR.RIGHT);

    if(WasButtonJustPressed(IN_ATTACK))
        tetromino.Rotate(false);
    if(WasButtonJustPressed(IN_ATTACK2))
        tetromino.Rotate(true);

    if(WasButtonJustPressed(IN_BACK))
        SetVar("next_gravity_ticks", 0);
    if(WasButtonJustPressed(IN_FORWARD))
        SwitchHoldTetromino();
    if(WasButtonJustPressed(IN_JUMP))
    {
        local times_moved = GetVar("active_tetromino").SnapToFloor();
        AddVar("score", 2 * times_moved);
        tetromino.Land();
    }
}

::CTFPlayer.SwitchHoldTetromino <- function()
{
    if(!GetVar("can_switch_hold"))
        return;

    local current_shape = GetVar("active_tetromino").shape;
    GetVar("active_tetromino").Destroy();
    SetVar("can_switch_hold", false);

    // if we have a shape in hold, create a new active tetromino with it
    // if we don't, create a new active tetromino from grabbag
    if(GetVar("hold_tetromino_shape"))
        SetVar("active_tetromino", Tetromino(this, GetVar("hold_tetromino_shape"), TETROMINO_TYPE.ACTIVE));
    else
        SetVar("active_tetromino", Tetromino(this, CycleGrabbag(), TETROMINO_TYPE.ACTIVE));

    SetVar("hold_tetromino_shape", current_shape);

    if(!GetVar("hold_tetromino_cluster_model"))
    {
        SetVar("hold_tetromino_cluster_model", CreateInstancedProp(this, GetClusterModelFromShape(current_shape)));
        local held_tetromino_ent = GetVar("hold_tetromino_cluster_model");
        held_tetromino_ent.SetOrigin(HELD_TETROMINO_POS);
        SetPropInt(held_tetromino_ent, "m_nRenderMode", kRenderTransColor);
    }
    else
        GetVar("hold_tetromino_cluster_model").SetModel(GetClusterModelFromShape(current_shape));

    SetEntityColor(GetVar("hold_tetromino_cluster_model"), TETROMINO_COLORS[current_shape]);
    SetVar("next_gravity_ticks", GetNextGravityTimeFromLevel());
    SetVar("lock_resets", 0);
    SetVar("lock_time_ticks", 0);
    UpdateGhostTetromino();
}

::CTFPlayer.UpdateGhostTetromino <- function()
{
    if(!GetVar("active_tetromino"))
        return;

    if(!GetVar("ghost_tetromino"))
        SetVar("ghost_tetromino", Tetromino(this, GetVar("active_tetromino").shape, TETROMINO_TYPE.GHOST));

    GetVar("ghost_tetromino").CopyTetromino(GetVar("active_tetromino"), 1);
    GetVar("ghost_tetromino").SnapToFloor();
}

::CTFPlayer.ResetEverything <- function()
{
    RemoveInstancedProps();
    InitPlayerVariables();
    SetVar("game_active", true);
    SetVar("active_tetromino", Tetromino(this, CycleGrabbag(), TETROMINO_TYPE.ACTIVE));
}