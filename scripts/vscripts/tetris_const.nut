::BLOCK_MODEL <- "models/tetris_block.mdl";
PrecacheModel(BLOCK_MODEL);

::BOARD_PIVOT <- FindByName(null, "board_pivot").GetOrigin();
::GRID_SIZE <- 64.0;
::BOARD_SIZE_OFFSCREEN <- 5;
::BOARD_SIZE <- Vector2D(10,20 + BOARD_SIZE_OFFSCREEN);
::BLOCK_OFFSET <- Vector(0,32,-32);

::HELD_TETROMINO_POS <- FindByName(null, "hold_tetromino_pos").GetOrigin();

::NEXT_TETROMINO_POS <- FindByName(null, "next_tetromino_pos").GetOrigin();
::NEXT_TETROMINO_INITIAL_OFFSET <- -112;
::NEXT_TETROMINO_OFFSET <- -96;
::NEXT_TETROMINO_COUNT <- 5;

::LOCK_DELAY_TICKS <- 33; // how long it takes for a tetromino to land after touching the ground
::LOCK_DELAY_RESET_LIMIT <- 8; // how many times you can cancel the lock

::LINE_CLEAR_DELAY_TICKS <- 22; // how long it takes after clearing a line to pause
::LINE_CLEAR_FLASH_INTERVAL <- 4; //  how often cleared lines should flash during the above pause

::MAJOR_ACTION_DISPLAY_TICKS <- 198 + LINE_CLEAR_DELAY_TICKS; // how long to display our latest major action (BACK-TO-BACK MINI T-SPIN SINGLE)
::MAJOR_ACTION_DISPLAY_TICKS_PERFECT_CLEAR <- 66; // how much longer to display our latest major action when we also got a perfect clear (BACK-TO-BACK TETRIS PERFECT CLEAR)

::DAS_INITIAL_TICKS <- 6; // how many ticks until DAS starts
::DAS_PERIOD_TICKS <- 4; // how many ticks inbetween DAS inputs

enum MAJOR_ACTION {
    SINGLE
    DOUBLE
    TRIPLE
    TETRIS
    MINI_TSPIN
    TSPIN
    MINI_TSPIN_SINGLE
    TSPIN_SINGLE
    TSPIN_DOUBLE
    TSPIN_TRIPLE
}

::MAJOR_ACTION_SCORE <- {
    [MAJOR_ACTION.SINGLE] = 100,
    [MAJOR_ACTION.DOUBLE] = 300,
    [MAJOR_ACTION.TRIPLE] = 500,
    [MAJOR_ACTION.TETRIS] = 800,
    [MAJOR_ACTION.MINI_TSPIN] = 100,
    [MAJOR_ACTION.TSPIN] = 400,
    [MAJOR_ACTION.MINI_TSPIN_SINGLE] = 200,
    [MAJOR_ACTION.TSPIN_SINGLE] = 800,
    [MAJOR_ACTION.TSPIN_DOUBLE] = 1200,
    [MAJOR_ACTION.TSPIN_TRIPLE] = 1600
}

::BACK_TO_BACK_SCORE_MULT <- 1.5;

enum PERFECT_CLEAR {
    SINGLE
    DOUBLE
    TRIPLE
    TETRIS
    BACK_TO_BACK_TETRIS
}

::PERFECT_CLEAR_SCORE <- {
    [PERFECT_CLEAR.SINGLE] = 800,
    [PERFECT_CLEAR.DOUBLE] = 1200,
    [PERFECT_CLEAR.TRIPLE] = 1800,
    [PERFECT_CLEAR.TETRIS] = 2000,
    [PERFECT_CLEAR.BACK_TO_BACK_TETRIS] = 3200
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
    [ROT_STATE.NONE + ROT_STATE.RIGHT] = [Vector2D(-1, 0), Vector2D(-1, -1), Vector2D(0, 2), Vector2D(-1, 2)],
    [ROT_STATE.RIGHT + ROT_STATE.NONE] = [Vector2D(1, 0), Vector2D(1, 1), Vector2D(0, -2), Vector2D(1, -2)],
    [ROT_STATE.RIGHT + ROT_STATE.TWO] = [Vector2D(1, 0), Vector2D(1, 1), Vector2D(0, -2), Vector2D(1, -2)],
    [ROT_STATE.TWO + ROT_STATE.RIGHT] = [Vector2D(-1, 0), Vector2D(-1, -1), Vector2D(0, 2), Vector2D(-1, 2)],
    [ROT_STATE.TWO + ROT_STATE.LEFT] = [Vector2D(1, 0), Vector2D(1, -1), Vector2D(0, 2), Vector2D(1, 2)],
    [ROT_STATE.LEFT + ROT_STATE.TWO] = [Vector2D(-1, 0), Vector2D(-1, 1), Vector2D(0, -2), Vector2D(-1, -2)],
    [ROT_STATE.LEFT + ROT_STATE.NONE] = [Vector2D(-1, 0), Vector2D(-1, 1), Vector2D(0, -2), Vector2D(-1, -2)],
    [ROT_STATE.NONE + ROT_STATE.LEFT] = [Vector2D(1, 0), Vector2D(1, -1), Vector2D(0, 2), Vector2D(1, 2)]
}

::WALL_KICK_DATA_I <- {
    [ROT_STATE.NONE + ROT_STATE.RIGHT] = [Vector2D(-2, 0), Vector2D(1, 0), Vector2D(-2, 1), Vector2D(1, -2)],
    [ROT_STATE.RIGHT + ROT_STATE.NONE] = [Vector2D(2, 0), Vector2D(-1, 0), Vector2D(2, -1), Vector2D(-1, 2)],
    [ROT_STATE.RIGHT + ROT_STATE.TWO] = [Vector2D(-1, 0), Vector2D(2, 0), Vector2D(-1, -2), Vector2D(2, 1)],
    [ROT_STATE.TWO + ROT_STATE.RIGHT] = [Vector2D(1, 0), Vector2D(-2, 0), Vector2D(1, 2), Vector2D(-2, -1)],
    [ROT_STATE.TWO + ROT_STATE.LEFT] = [Vector2D(2, 0), Vector2D(-1, 0), Vector2D(2, -1), Vector2D(-1, 2)],
    [ROT_STATE.LEFT + ROT_STATE.TWO] = [Vector2D(-2, 0), Vector2D(1, 0), Vector2D(-2, 1), Vector2D(1, -2)],
    [ROT_STATE.LEFT + ROT_STATE.NONE] = [Vector2D(1, 0), Vector2D(-2, 0), Vector2D(1, 2), Vector2D(-2, -1)],
    [ROT_STATE.NONE + ROT_STATE.LEFT] = [Vector2D(-1, 0), Vector2D(2, 0), Vector2D(-1, -2), Vector2D(2, 1)]
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

enum TETROMINO_ACTION {
    MOVEMENT
    ROTATION
    ROTATION_WALLKICK
}

enum MOVE_DIR {
    NONE
    LEFT
    RIGHT
    DOWN
    UP
}

::MOVE_DIR_POS <- {
    [MOVE_DIR.NONE] = Vector2D(0, 0),
    [MOVE_DIR.LEFT] = Vector2D(-1, 0),
    [MOVE_DIR.RIGHT] = Vector2D(1, 0),
    [MOVE_DIR.DOWN] = Vector2D(0, 1),
    [MOVE_DIR.UP] = Vector2D(0, -1)
}

::GetMoveDir <- function(dir)
{
    return MOVE_DIR_POS[dir];
}