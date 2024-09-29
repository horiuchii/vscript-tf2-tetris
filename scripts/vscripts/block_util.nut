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

::CTFPlayer.ClearFullLines <- function()
{
    local lines_cleared = 0;

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
            foreach(block in blocks_in_line)
            {
                block.ent.Destroy();
                GetVar("board_blocks")[block.pos.x][block.pos.y] = null;
            }
            //TODO: have this happen once after the for loop. this would be faster and fix visual bugs
            MoveAllBlocksAboveYDown(y);
            lines_cleared += 1;
        }
    }

    return lines_cleared;
}

::CTFPlayer.MoveAllBlocksAboveYDown <- function(target_y)
{
    for(local y = BOARD_SIZE.y; y > 0; y--)
    {
        if(!(y < target_y))
            continue;

        for(local x = 1; x < BOARD_SIZE.x + 1; x++)
        {
            local block = GetVar("board_blocks")[x][y];
            if(!block)
                continue;

            GetVar("board_blocks")[block.pos.x][block.pos.y] = null;
            GetVar("board_blocks")[block.pos.x][block.pos.y + 1] = block;
            block.SetPos(block.pos + GetMoveDir(MOVE_DIR.DOWN));
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