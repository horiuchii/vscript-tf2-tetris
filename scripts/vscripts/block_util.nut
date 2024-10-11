::RotateVector2D_90Degrees <- function(input, origin, clockwise)
{
    local output = Vector2D(0,0);

    if(clockwise)
    {
        output.x = -(input.y - origin.y) + origin.x;
        output.y = (input.x - origin.x) + origin.y;
    }
    else
    {
        output.x = (input.y - origin.y) + origin.x;
        output.y = -(input.x - origin.x) + origin.y;
    }

    return output;
}

::BoardToWorld <- function(board_pos)
{
    return BOARD_PIVOT - (Vector(0, board_pos.x, board_pos.y) * GRID_SIZE);
}

::WorldToBoard <- function(world_pos)
{
    local board_pos = (BOARD_PIVOT - world_pos) / GRID_SIZE;
    return Vector2D(board_pos.y, board_pos.z);
}

::CTFPlayer.IsBoardEmpty <- function()
{
    for(local y = BOARD_SIZE.y - 1; y > 0; y--)
    {
        if(GetVar("lines_to_clear").find(y) != null)
            continue;

        for(local x = 1; x < BOARD_SIZE.x + 1; x++)
        {
            if(GetVar("board_blocks")[x][y])
               return false;
        }
    }

    return true;
}

::CTFPlayer.GetBlocksAtY <- function(target_y)
{
    local blocks_in_line = [];
    for(local x = 1; x < BOARD_SIZE.x + 1; x++)
    {
        if(GetVar("board_blocks")[x][target_y])
            blocks_in_line.append(GetVar("board_blocks")[x][target_y]);
    }
    return blocks_in_line;
}

::CTFPlayer.MarkFullLinesForClearing <- function()
{
    local lines_cleared = [];

    for(local y = 0; y < BOARD_SIZE.y; y++)
    {
        local blocks_in_line = [];
        for(local x = 1; x < BOARD_SIZE.x + 1; x++)
        {
            if(GetVar("board_blocks")[x][y])
                blocks_in_line.append(GetVar("board_blocks")[x][y]);
        }

        if(blocks_in_line.len() == BOARD_SIZE.x)
        {
            lines_cleared.append(y);
        }
    }

    if(lines_cleared.len() > 0)
    {
        SetVar("line_clear_delay_ticks", LINE_CLEAR_DELAY_TICKS);
        SetVar("line_clear_flash_ticks", 0);
        SetVar("lines_to_clear", lines_cleared);
    }

    return lines_cleared.len();
}

::CTFPlayer.ClearLines <- function(target_y_array)
{
    for(local y = 0; y < BOARD_SIZE.y; y++)
    {
        if(target_y_array.find(y) != null)
        {
            for(local x = 1; x < BOARD_SIZE.x + 1; x++)
            {
                GetVar("board_blocks")[x][y].ent.Destroy();
                GetVar("board_blocks")[x][y] = null;
            }
        }
    }

    MoveAllBlocksAboveYDown(target_y_array);
}

::CTFPlayer.MoveAllBlocksAboveYDown <- function(target_y_array)
{
    local move_down = array(BOARD_SIZE.y, 0);

    // pre calculate how many times each row will move down
    for(local y = BOARD_SIZE.y - 1; y > 0; y--)
    {
        foreach(target_y in target_y_array)
        {
            if(y < target_y)
                move_down[y] += 1;
        }
    }

    for(local y = BOARD_SIZE.y - 1; y > 0; y--)
    {
        if(!move_down[y])
            continue;

        for(local x = 1; x < BOARD_SIZE.x + 1; x++)
        {
            local block = GetVar("board_blocks")[x][y];
            if(!block)
                continue;

            GetVar("board_blocks")[block.pos.x][block.pos.y] = null;
            GetVar("board_blocks")[block.pos.x][block.pos.y + move_down[y]] = block;
            block.SetPos(block.pos + (GetMoveDir(MOVE_DIR.DOWN) * move_down[y]));
        }
    }
}

::CTFPlayer.CycleGrabbag <- function()
{
    if(GetVar("grab_bag").len() <= TETROMINO_COUNT)
    {
        local new_grabbag = [];
        foreach(key, table in TETROMINOS)
            new_grabbag.append(key);

        ShuffleArray(new_grabbag);
        GetVar("grab_bag").extend(new_grabbag);
    }

    local removed_tetromino = GetVar("grab_bag").remove(0);
    OnGrabBagUpdated(removed_tetromino);
    return removed_tetromino;
}

::CTFPlayer.GetNextGravityTimeFromLevel <- function()
{
    local gravity_thresholds = [];
    foreach(level, gravity in GRAVITY_LEVELS)
        gravity_thresholds.append(level);

    gravity_thresholds.sort();
    gravity_thresholds.reverse();

    foreach(level_threshold in gravity_thresholds)
    {
        if(GetVar("level") >= level_threshold)
        {
            return GRAVITY_LEVELS[level_threshold];
        }
    }
}

::CTFPlayer.PlayMajorActionSound <- function(major_action, level_up)
{
    if(major_action == null)
        return;

    local sound;

    switch(major_action)
    {
        case MAJOR_ACTION.SINGLE: sound = "single"; break;
        case MAJOR_ACTION.DOUBLE: sound = "double"; break;
        case MAJOR_ACTION.TRIPLE: sound = "triple"; break;
        case MAJOR_ACTION.TETRIS: sound = "tetris"; break;
        case MAJOR_ACTION.MINI_TSPIN: sound = "mini_tspin"; break;
        case MAJOR_ACTION.TSPIN: sound = "tspin"; break;
        case MAJOR_ACTION.MINI_TSPIN_SINGLE: sound = "mini_tspin_single"; break;
        case MAJOR_ACTION.TSPIN_SINGLE: sound = "tspin_single"; break;
        case MAJOR_ACTION.TSPIN_DOUBLE: sound = "tspin_double"; break;
        case MAJOR_ACTION.TSPIN_TRIPLE: sound = "tspin_triple"; break;
    }

    if(GetVar("back_to_back_combo") > 1)
    {
        PlaySoundForPlayer({sound_name = "tetris_back_to_back.mp3"});
        RunWithDelay(0.8, function(){
            PlaySoundForPlayer({sound_name = "tetris_" + sound + ".mp3"});
        })
        if(level_up)
        {
            RunWithDelay(2.3, function(){
                PlaySoundForPlayer({sound_name = "tetris_levelup.mp3"});
            })
        }
    }
    else
    {
        PlaySoundForPlayer({sound_name = "tetris_" + sound + ".mp3"});
        if(level_up)
        {
            RunWithDelay(1.5, function(){
                PlaySoundForPlayer({sound_name = "tetris_levelup.mp3"});
            })
        }

    }
}