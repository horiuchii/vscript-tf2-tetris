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

    SetVar("next_update_hud", 0);

    SetVar("next_apply_gravity_ticks", 0);
    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);

    SetVar("score", 0);
    SetVar("lines_cleared", 0);
    SetVar("level", 0);

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

    if(GetVar("next_update_hud") < Time())
    {
        SetVar("next_update_hud", Time() + 0.1);
        UpdateHUD();
    }

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

    if(GetVar("game_paused"))
        SendGameText(-1, -1, 3, "255 255 255", "PAUSED\nPRESS [SCOREBOARD] TO UNPAUSE");
    else if(!GetVar("game_active"))
        SendGameText(-1, -1, 3, "255 255 255", "GAME OVER\nPRESS [SCOREBOARD] TO PLAY AGAIN");
    else
        SendGameText(-1, -1, 3, "255 255 255", "");
}

::CTFPlayer.HandleTetrominoLock <- function()
{
    SendGameText(-1, -1, 4, "255 255 255", GetVar("lock_resets") + "");

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

        local percent = remapclamped(GetVar("lock_time_ticks").tofloat(), LOCK_DELAY_TICKS, 0, 1, 0);
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
    if(GetVar("next_apply_gravity_ticks") == 0)
    {
        local soft_drop_active = IsHoldingButton(IN_BACK);
        SetVar("next_apply_gravity_ticks", soft_drop_active ? GetNextGravityTimeFromLevel()/10 : GetNextGravityTimeFromLevel());

        if(soft_drop_active && !GetVar("active_tetromino").DoesCollideIfMoveInDirection(MOVE_DIR.DOWN))
            AddVar("score", 1);

        GetVar("active_tetromino").Move(MOVE_DIR.DOWN);
    }
    else
        SubtractVar("next_apply_gravity_ticks", 1);
}

::CTFPlayer.OnTetrominoLand <- function()
{
    SetVar("lock_time_ticks", 0);
    SetVar("lock_resets", 0);
    SetVar("active_tetromino", Tetromino(this, CycleGrabbag(), TETROMINO_TYPE.ACTIVE));
    SetVar("can_switch_hold", true);
    SetVar("next_apply_gravity_ticks", GetNextGravityTimeFromLevel());

    // Handle clearing lines
    local lines_cleared = ClearFullLines();
    if(lines_cleared > 0)
    {
        local score;
        switch(lines_cleared)
        {
            case 1: score = 100; break;
            case 2: score = 300; break;
            case 3: score = 500; break;
            case 4: score = 800; break;
        }
        AddVar("score", score * (GetVar("level") + 1));

        // Check if we should go up a level
        local lines_cleared_pre = GetVar("lines_cleared");
        AddVar("lines_cleared", lines_cleared);
        if(floor(lines_cleared_pre / 10) < floor(GetVar("lines_cleared") / 10))
            AddVar("level", 1);
    }

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
        SetVar("next_apply_gravity_ticks", 0);
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
    SetVar("next_apply_gravity_ticks", GetNextGravityTimeFromLevel());
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