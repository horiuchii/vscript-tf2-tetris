::BLOCK_MODEL <- "models/tetris_block.mdl";
PrecacheModel(BLOCK_MODEL);

::BOARD_PIVOT <- FindByName(null, "board_pivot").GetOrigin();
::GRID_SIZE <- 64.0;
::BOARD_SIZE <- Vector2D(10,20);
::BLOCK_OFFSET <- Vector(0,32,-32);

::HELD_TETROMINO_POS <- FindByName(null, "hold_tetromino_pos").GetOrigin();

::NEXT_TETROMINO_POS <- FindByName(null, "next_tetromino_pos").GetOrigin();
::NEXT_TETROMINO_INITIAL_OFFSET <- -112;
::NEXT_TETROMINO_OFFSET <- -96;
::NEXT_TETROMINO_COUNT <- 5;

::LOCK_DELAY_TICKS <- 33;
::LOCK_DELAY_RESET_LIMIT <- 15;

::LINE_CLEAR_DELAY <- 0.666;
::AUTO_SHIFT_DELAY <- 0.183;

::BoardToWorld <- function(board_pos)
{
    return BOARD_PIVOT - (Vector(0, board_pos.x, board_pos.y) * GRID_SIZE);
}

::WorldToBoard <- function(world_pos)
{
    local board_pos = (BOARD_PIVOT - world_pos) / GRID_SIZE;
    return Vector2D(board_pos.y, board_pos.z);
}

enum TETROMINO_TYPE {
    ACTIVE
    GHOST
}

::TETROMINO_COLORS <- {
    "I" : [49, 199, 239, 255]
    "O" : [247, 211, 8, 255]
    "T" : [173, 77, 156, 255]
    "S" : [66, 182, 66, 255]
    "Z" : [239, 32, 41, 255]
    "J" : [90, 101, 173, 255]
    "L" : [239, 121, 33, 255]
}

::TETROMINOS <- {
    "I" : [Vector2D(0, 0), Vector2D(-1, 0), Vector2D(1, 0), Vector2D(2, 0)]
    "O" : [Vector2D(0, 0), Vector2D(0, -1), Vector2D(1, 0), Vector2D(1, -1)]
    "T" : [Vector2D(0, 0), Vector2D(-1, 0), Vector2D(1, 0), Vector2D(0, -1)]
    "S" : [Vector2D(0, 0), Vector2D(-1, 0), Vector2D(0, -1), Vector2D(1, -1)]
    "Z" : [Vector2D(0, 0), Vector2D(1, 0), Vector2D(0, -1), Vector2D(-1, -1)]
    "J" : [Vector2D(0, 0), Vector2D(-1, 0), Vector2D(1, 0), Vector2D(-1, -1)]
    "L" : [Vector2D(0, 0), Vector2D(-1, 0), Vector2D(1, 0), Vector2D(1, -1)]
}

::TETROMINO_COUNT <- TETROMINOS.len();

::BLOCK_CLUSTER_MODEL_PREFIX <- "models/tetris_block_cluster_";
::GetClusterModelFromShape <- function(shape){return BLOCK_CLUSTER_MODEL_PREFIX + shape + ".mdl"};
foreach(tetromino_shape, tetromino_data in TETROMINOS)
    PrecacheModel(GetClusterModelFromShape(tetromino_shape));

enum ROT_STATE {
    NONE = "0"
    RIGHT = "1" // Clockwise
    TWO = "2"
    LEFT = "3" // Counter-Clockwise
}

::GetRotationDebugName <- function(rotation)
{
    local name = "";
    switch(rotation)
    {
        case 0: name = "NONE"; break;
        case 1: name = "RIGHT/CLOCKWISE"; break;
        case 2: name = "TWO"; break;
        case 3: name = "LEFT/COUNTER-CLOCKWISE"; break;
    }
    return name;
}

::WALL_KICK_DATA <- {
    [ROT_STATE.NONE + ROT_STATE.RIGHT] = [Vector2D(-1, 0), Vector2D(-1, 1), Vector2D(0, -2), Vector2D(-1, -2)],
    [ROT_STATE.RIGHT + ROT_STATE.NONE] = [Vector2D(1, 0), Vector2D(1, -1), Vector2D(0, 2), Vector2D(1, 2)],
    [ROT_STATE.RIGHT + ROT_STATE.TWO] = [Vector2D(1, 0), Vector2D(1, -1), Vector2D(0, 2), Vector2D(1, 2)],
    [ROT_STATE.TWO + ROT_STATE.RIGHT] = [Vector2D(-1, 0), Vector2D(-1, 1), Vector2D(0, -2), Vector2D(-1, -2)],
    [ROT_STATE.TWO + ROT_STATE.LEFT] = [Vector2D(1, 0), Vector2D(1, 1), Vector2D(0, -2), Vector2D(1, -2)],
    [ROT_STATE.LEFT + ROT_STATE.TWO] = [Vector2D(-1, 0), Vector2D(-1, -1), Vector2D(0, 2), Vector2D(-1, 2)],
    [ROT_STATE.LEFT + ROT_STATE.NONE] = [Vector2D(-1, 0), Vector2D(-1, -1), Vector2D(0, 2), Vector2D(-1, 2)],
    [ROT_STATE.NONE + ROT_STATE.LEFT] = [Vector2D(1, 0), Vector2D(1, 1), Vector2D(0, -2), Vector2D(1, -2)]
}

::WALL_KICK_DATA_I <- {
    [ROT_STATE.NONE + ROT_STATE.RIGHT] = [Vector2D(-2, 0), Vector2D(1, 0), Vector2D(-2, -1), Vector2D(1, 2)],
    [ROT_STATE.RIGHT + ROT_STATE.NONE] = [Vector2D(2, 0), Vector2D(-1, 0), Vector2D(2, 1), Vector2D(-1, -2)],
    [ROT_STATE.RIGHT + ROT_STATE.TWO] = [Vector2D(-1, 0), Vector2D(2, 0), Vector2D(-1, 2), Vector2D(2, -1)],
    [ROT_STATE.TWO + ROT_STATE.RIGHT] = [Vector2D(1, 0), Vector2D(-2, 0), Vector2D(1, -2), Vector2D(-2, 1)],
    [ROT_STATE.TWO + ROT_STATE.LEFT] = [Vector2D(2, 0), Vector2D(-1, 0), Vector2D(2, 1), Vector2D(-1, -2)],
    [ROT_STATE.LEFT + ROT_STATE.TWO] = [Vector2D(-2, 0), Vector2D(1, 0), Vector2D(-2, -1), Vector2D(1, 2)],
    [ROT_STATE.LEFT + ROT_STATE.NONE] = [Vector2D(1, 0), Vector2D(-2, 0), Vector2D(1, -2), Vector2D(-2, 1)],
    [ROT_STATE.NONE + ROT_STATE.LEFT] = [Vector2D(-1, 0), Vector2D(2, 0), Vector2D(-1, 2), Vector2D(2, -1)]
}

::GRAVITY_LEVELS <- {
    [29] = 1,
    [19] = 2,
    [16] = 3,
    [13] = 4,
    [10] = 5,
    [9] = 6,
    [8] = 8,
    [7] = 14,
    [6] = 19,
    [5] = 25,
    [4] = 30,
    [3] = 36,
    [2] = 41,
    [1] = 47,
    [0] = 52
}

enum MOVE_DIR {
    LEFT
    RIGHT
    DOWN
}

::MOVE_DIR_POS <- {
    [MOVE_DIR.LEFT] = Vector2D(-1, 0),
    [MOVE_DIR.RIGHT] = Vector2D(1, 0),
    [MOVE_DIR.DOWN] = Vector2D(0, 1)
}

::GetMoveDir <- function(dir)
{
    return MOVE_DIR_POS[dir];
}