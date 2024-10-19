DefineGamemode(class extends Gamemode
{
    name = "Mission"
    cookie = "hiscore_mission"
    default_hiscore = 0;

    allow_increment_level = false;

    mission = null;
    recent_missions = null;
    mission_no = 0;
    ticks_left = 0;

    MISSION_TICKSREMAINING = {
        [16] = 660,   //10 sec
        [15] = 990,   //15 sec
        [9]  = 1320,  //20 sec
        [6]  = 1650,  //25 sec
        [5]  = 1980,  //30 sec
        [4]  = 2640,  //40 sec
        [3]  = 3300,  //50 sec
        [2]  = 3960,  //60 sec
        [1]  = 7620,  //70 sec
        [0]  = 6600,  //100 sec
    }
    NUM_BARS = 10;

    function GenerateDesc(client)
    {
        return "Highscore: " + CookieUtil.Get(client, cookie) + "\n\nComplete as many missions as\nyou can under a strict time limit!";
    }

    function OnRoundReset()
    {
        base.OnRoundReset();
        mission_no = 0;
        ticks_left = GetTimeLeftFromLevel();
    }

    function OnTick()
    {
        player.SetVar("major_action_display_ticks", 0); //never display our major action, replaced with time left
        ticks_left -= 1.0;
    }

    function UpdateHUD()
    {
        local stats = "HISCORE\n" + CookieUtil.Get(player, cookie) + "\n\nMISSION\n" + mission_no + "\n\nLEVEL\n" + (player.GetVar("level") + 1) + "\n\nTIME LEFT\n" + FormatTime(TicksToTime(ticks_left));
        player.SendGameText(-0.666, -0.475, CHAN_STATS, "255 255 255", stats);

        local string = "Mission:\nClear 4 lines twice in a row";
        player.SendGameText(-1, -0.005, CHAN_MAJOR_ACTION, "255 255 255", string);
    }

    function OnGameOver(victory)
    {
        if(mission_no > CookieUtil.Get(player, cookie))
            CookieUtil.Set(player, cookie, mission_no);
    }

    function GetTimeLeftFromLevel()
    {
        local time_thresholds = [];
        foreach(level, time_left in MISSION_TICKSREMAINING)
            time_thresholds.append(level);

        time_thresholds.sort();
        time_thresholds.reverse();

        foreach(level_threshold in time_thresholds)
        {
            if(player.GetVar("level") >= level_threshold)
            {
                return MISSION_TICKSREMAINING[level_threshold];
            }
        }
    }
})

class Mission
{
    name = "";
    player = null;
    function OnMissionStart(){}
    function OnLineClear(){}
    function GenerateDesc(){}
    function OnMissionEnd(){}

    function constructor(player)
    {
        this.player = player;
    }
}

::Missions <- {};

::DefineMission <- function(mission)
{
    Missions[mission.name] <- mission;
}

//clear 2-3 lines at once
DefineMission(class extends Mission
{
    name = "line_clear_basic"
})

//clear 4 lines at once / twice in a row
DefineMission(class extends Mission
{

})

//clear a total of 5 lines
DefineMission(class extends Mission
{

})

//clear a total of 5 lines (speed up)
DefineMission(class extends Mission
{

})

//clear a total of 2-5 lines with x tetromino
DefineMission(class extends Mission
{

})

//clear 2/3 lines at once with x tetromino (no I)
DefineMission(class extends Mission
{

})

//clear a total of 3-5 lines where only one tetromino is dealt
DefineMission(class extends Mission
{

})

//clear a total of 5 lines where only two tetrominoes are dealt
DefineMission(class extends Mission
{

})

//clear 2-3 lines, skipping 1 (line hurdle)
DefineMission(class extends Mission
{

})

//clear 1-2 marked lines (line target)
DefineMission(class extends Mission
{

})

//clear 1 line with no rotation (tetrominoes spawn with random rotation)
DefineMission(class extends Mission
{

})