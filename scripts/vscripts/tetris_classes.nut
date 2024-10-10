class Block
{
    ent = null;
    pos = Vector2D(0, 0);
    tetromino = null;
    owning_player = null;

    function constructor(player, pos, tetromino)
    {
        this.owning_player = player;
        this.tetromino = tetromino;

        this.ent = CreateInstancedProp(this.owning_player, BLOCK_MODEL);
        SetPropInt(ent, "m_nRenderMode", kRenderTransColor);
        this.SetPos(pos + Vector2D(BOARD_SIZE.x/2, BOARD_SIZE_OFFSCREEN));
    }

    function _tostring()
    {
        return "[" + ent.entindex() + "] Block";
    }

    function SetColor(shape, mult, alpha)
    {
        local block_color = TETROMINO_COLORS[shape];
        SetEntityColor(ent, [(block_color[0] * mult).tointeger(), (block_color[1] * mult).tointeger(), (block_color[2] * mult).tointeger(), alpha]);
    }

    function SetColorCustom(color)
    {
        SetEntityColor(ent, color);
    }

    function Rotate(pivot_pos, clockwise)
    {
        return RotateVector2D_90Degrees(pos, pivot_pos, clockwise);
    }

    function SetPos(new_pos)
    {
        pos = new_pos;
        ent.SetOrigin(BoardToWorld(pos) + BLOCK_OFFSET + (tetromino.type == TETROMINO_TYPE.GHOST ? Vector(1, 0, 0) : Vector(0, 0, 0)));
    }

    function DoesCollide(pos)
    {
        //if our new pos is above the board, dont check
        if(pos.y < 0)
            return false;
        //check if we are in board bounds and a block doesn't exist where we want to be
        if((pos.x > 0 && pos.x <= BOARD_SIZE.x) && (pos.y < BOARD_SIZE.y) && !owning_player.GetVar("board_blocks")[pos.x][pos.y])
            return false;

        return true;
    }
}
::Block <- Block;

class Tetromino
{
    shape = null;
    blocks = null;
    owning_player = null;
    type = null;
    rotation = 0;
    pivot = null;

    function constructor(player, shape, type)
    {
        this.owning_player = player;
        this.shape = shape;
        this.blocks = [];
        this.type = type;
        foreach(i, position in TETROMINOS[shape])
        {
            local block = Block(owning_player, position, this);
            blocks.append(block);
        }
        ColorBlocks(1);

        switch(shape)
        {
            case "I": pivot = blocks[0].pos + Vector2D(0.5, 0.5); break;
            case "O": pivot = blocks[0].pos + Vector2D(0.5, -0.5); break;
            default: pivot = blocks[0].pos;
        }

        // check if we are spawning inside a block
        if(DoesCollideIfMoveInDirection(MOVE_DIR.NONE))
            owning_player.DoGameOver();
    }

    function _tostring()
    {
        return "[Tetromino] " + ArrayToStr(blocks);
    }

    function Destroy()
    {
        foreach(block in blocks)
            block.ent.Destroy();
    }

    function ColorBlocks(mult)
    {
        foreach(block in blocks)
        {
            block.SetColor(shape, mult, type == TETROMINO_TYPE.GHOST ? 50 : 255)
        }
    }

    function Rotate(clockwise)
    {
        local new_rotation_offset = (rotation + (clockwise ? 1 : -1));
        local new_rotation = (new_rotation_offset < 0 ? 4 : 0) + new_rotation_offset % 4;

        local wall_kick_offset_table = shape == "I" ? WALL_KICK_DATA_I : WALL_KICK_DATA;
        local wall_kick_offset_array = wall_kick_offset_table[rotation.tostring() + new_rotation.tostring()];

        //attempt to rotate 5 times, first time using no offset, the other 4 times use an offset from the wall kick array
        for(local i = 0; i < 5; i++)
        {
            local wall_kick_offset = Vector2D(0, 0);
            if(i != 0)
                wall_kick_offset = wall_kick_offset_array[i - 1];

            local new_block_positions = [];
            foreach(block in blocks)
                new_block_positions.append(block.Rotate(pivot, clockwise) + wall_kick_offset)

            if(!DoesCollide(new_block_positions))
            {
                rotation = new_rotation;
                pivot += wall_kick_offset;

                foreach(block_index, block in blocks)
                    block.SetPos(new_block_positions[block_index])

                if(type == TETROMINO_TYPE.ACTIVE)
                {
                    //if we are mid lock, cancel it
                    if(owning_player.GetVar("lock_time_ticks") > 0)
                    {
                        owning_player.AddVar("lock_resets", 1);
                        owning_player.SetVar("lock_time_ticks", 0);
                        ColorBlocks(1);
                    }
                    owning_player.SetVar("last_tetromino_action", i == 0 ? TETROMINO_ACTION.ROTATION : TETROMINO_ACTION.ROTATION_WALLKICK);
                    owning_player.UpdateGhostTetromino();
                }

                break;
            }
        }
    }

    function SetBlockPos(block_positions, offset)
    {
        foreach(i, block in blocks)
            block.SetPos(block_positions[i] + offset);
    }

    function DoesCollide(block_positions)
    {
        foreach(i, block in blocks)
        {
            if(block.DoesCollide(block_positions[i]))
            {
                return true;
            }
        }
        return false;
    }

    function DoesCollideIfMoveInDirection(direction)
    {
        local new_block_positions = [];
        foreach(block in blocks)
            new_block_positions.append(block.pos + GetMoveDir(direction))

        return DoesCollide(new_block_positions);
    }

    function Move(direction)
    {
        if(!DoesCollideIfMoveInDirection(direction))
        {
            foreach(block in blocks)
                block.SetPos(block.pos + GetMoveDir(direction));

            pivot += GetMoveDir(direction);

            if(type == TETROMINO_TYPE.ACTIVE)
            {
                owning_player.SetVar("last_tetromino_action", TETROMINO_ACTION.MOVEMENT);
                owning_player.UpdateGhostTetromino();
            }
            return true;
        }
        return false;
    }

    function MoveOffset(pos_offset)
    {
        foreach(block in blocks)
            block.SetPos(block.pos + pos_offset);
    }

    function Land()
    {
        //are we in bounds? if not, end game
        local blocks_oob = 0;
        foreach(block in blocks)
            if(block.pos.y < BOARD_SIZE_OFFSCREEN)
            {
                blocks_oob += 1;
            }

        if(blocks_oob == blocks.len())
        {
            owning_player.DoGameOver();
            return;
        }

        //put current tetromino in board array
        foreach(block in blocks)
        {
            SetPropBool(block.ent, "m_bGlowEnabled", true);
            owning_player.GetVar("board_blocks")[block.pos.x][block.pos.y] = block;
        }

        ColorBlocks(0.75);

        owning_player.OnTetrominoLand();
    }

    function SnapToFloor()
    {
        local new_block_positions = [];
        foreach(block in blocks)
            new_block_positions.append(block.pos);

        local move_down = -1;
        do
        {
            foreach(i, block_pos in new_block_positions)
                new_block_positions[i] = (block_pos + GetMoveDir(MOVE_DIR.DOWN))
            move_down++;
        }
        while (!DoesCollide(new_block_positions))

        MoveOffset(Vector2D(0, move_down));
        return move_down;
    }

    function GetGhostBlockPos()
    {
        local new_block_positions = [];
        foreach(block in blocks)
            new_block_positions.append(block.pos);

        do
        {
            foreach(i, block_pos in new_block_positions)
                new_block_positions[i] = (block_pos + GetMoveDir(MOVE_DIR.DOWN))
        }
        while (!DoesCollide(new_block_positions))

        return new_block_positions;
    }
}
::Tetromino <- Tetromino;