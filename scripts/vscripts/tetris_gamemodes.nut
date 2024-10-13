class Gamemode
{
    name = "";
    cookie = "";
    default_hiscore = 0;

    allow_increment_level = true;

    player = null;

    function constructor(player)
    {
        this.player = player;
    }

    function GenerateDesc(client){return "\n\n\n";}

    function OnRoundReset()
    {
        FindByName(null, "point_viewcontrol").AcceptInput("enable", "", player, player);
        player.RemoveInstancedProps();
        player.ResetTetrisVariables();
        player.CreateNewActiveTetromino(player.CycleGrabbag(), true);
    }

    function OnTick() {}

    function GetHUDStats() {}

    function OnTetrominoLand(lines_cleared) {}
    function OnGameOver(victory) {}
}

::Gamemodes <- [];

::DefineGamemode <- function(gamemode)
{
    Cookies.Table[gamemode.cookie] <- {default_value = gamemode.default_hiscore};
    Gamemodes.append(gamemode);
}

DefineGamemode(class extends Gamemode
{
    name = "Marathon"
    cookie = "highscore_marathon"
    default_hiscore = 0;

    function GenerateDesc(client)
    {
        return "Highscore: " + CookieUtil.Get(client, cookie) + "\n\nSee how long you can last\nin an endless tetris!";
    }

    function GetHUDStats()
    {
        local stats = "HISCORE\n" + CookieUtil.Get(player, cookie) + "\n\nSCORE\n" + player.GetVar("score") + "\n\nLINES\n" + player.GetVar("lines_cleared") + "\n\nLEVEL\n" + (player.GetVar("level") + 1);
        player.SendGameText(-0.666, -0.375, CHAN_STATS, "255 255 255", stats);
    }

    function OnGameOver(victory)
    {
        if(player.GetVar("score") > CookieUtil.Get(player, cookie))
            CookieUtil.Set(player, cookie, player.GetVar("score"));
    }
})

DefineGamemode(class extends Gamemode
{
    name = "40 Line"
    cookie = "hiscore_40lines"
    default_hiscore = 0;

    allow_increment_level = false;

    ticks_elapsed = 0;
    lines_remaining = 40;

    function GenerateDesc(client)
    {
        return "Best Time: " + FormatTime(TicksToTime(CookieUtil.Get(client, cookie))) + "\n\nRace to clear 40 lines\nas fast as you can!";
    }

    function OnRoundReset()
    {
        base.OnRoundReset();
        ticks_elapsed = 0;
        lines_remaining = 40;
        player.SetVar("level", 10);
    }

    function OnTick()
    {
        ticks_elapsed++;
    }

    function GetHUDStats()
    {
        local stats = "TOP TIME\n" + FormatTime(TicksToTime(CookieUtil.Get(player, cookie))) + "\n\nTIME\n" + FormatTime(TicksToTime(ticks_elapsed)) + "\n\nLINES\n" + lines_remaining;
        player.SendGameText(-0.666, -0.475, CHAN_STATS, "255 255 255", stats);
    }

    function OnTetrominoLand(lines_cleared)
    {
        lines_remaining = max(lines_remaining - lines_cleared, 0);

        if(lines_remaining == 0)
        {
            player.DoGameOver(true);
        }
    }

    function OnGameOver(victory)
    {
        if(!victory)
            return;

        if(ticks_elapsed < CookieUtil.Get(player, cookie))
           CookieUtil.Set(player, cookie, ticks_elapsed);
    }
})

DefineGamemode(class extends Gamemode
{
    name = "Ultra"
    cookie = "hiscore_ultra"
    default_hiscore = 39534;

    allow_increment_level = false;

    ticks_remaining = 7920; //2 min

    function GenerateDesc(client)
    {
        return "Highscore: " + CookieUtil.Get(client, cookie) + "\n\nScore as many points as\nyou can within 2 minutes!";
    }

    function OnRoundReset()
    {
        base.OnRoundReset();
        ticks_remaining = 7920; //2 min
        player.SetVar("level", 10);
    }

    function OnTick()
    {
        if(ticks_remaining == 0)
        {
            player.DoGameOver(true);
        }

        ticks_remaining--;
    }

    function GetHUDStats()
    {
        local stats = "TIME LEFT\n" + FormatTime(TicksToTime(ticks_remaining)) + "\n\nHISCORE\n" + CookieUtil.Get(player, cookie) + "\n\nSCORE\n" + player.GetVar("score");
        player.SendGameText(-0.661, -0.475, CHAN_STATS, "255 255 255", stats);
    }

    function OnGameOver(victory)
    {
        if(!victory)
            return;

        if(player.GetVar("score") > CookieUtil.Get(player, cookie))
            CookieUtil.Set(player, cookie, player.GetVar("score"));
    }
})

DefineGamemode(class extends Gamemode
{
    name = "Mission"
    cookie = "hiscore_mission"
    default_hiscore = 0;

    allow_increment_level = false;

    mission_no = 0;

    function GenerateDesc(client)
    {
        return "Highscore: " + CookieUtil.Get(client, cookie) + "\n\nComplete as many missions as\nyou can under a strict time limit!";
    }

    function OnRoundReset()
    {
        base.OnRoundReset();
        mission_no = 0;
    }

    function GetHUDStats()
    {
        local stats = "HISCORE\n" + CookieUtil.Get(player, cookie) + "\n\nMISSION\n" + mission_no + "\n\nLEVEL\n" + (player.GetVar("level") + 1);
        player.SendGameText(-0.666, -0.475, CHAN_STATS, "255 255 255", stats);
    }

    function OnGameOver(victory)
    {
        if(mission_no > CookieUtil.Get(player, cookie))
            CookieUtil.Set(player, cookie, mission_no);
    }
})