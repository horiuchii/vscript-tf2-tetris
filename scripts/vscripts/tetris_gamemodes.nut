class Gamemode
{
    allow_increment_level = true;

    player = null;

    function constructor(player)
    {
        this.player = player;
    }

    function OnRoundReset()
    {
        FindByName(null, "point_viewcontrol").AcceptInput("enable", "", player, player);
        player.RemoveInstancedProps();
        player.ResetTetrisVariables();
        player.CreateNewActiveTetromino(player.CycleGrabbag(), true);
    }

    function OnTick() {}

    function DrawHUDStats() {}

    function OnTetrominoLand(lines_cleared) {}
    function OnGameOver(victory) {}
}

enum GAMEMODE {
    MARATHON
    FORTYLINE
    ULTRA
    MISSION
}

::Gamemodes <- {}

Gamemodes[GAMEMODE.MARATHON] <- class extends Gamemode
{
    function DrawHUDStats()
    {
        local stats = "HISCORE\n" + CookieUtil.Get(player, "highscore_marathon") + "\n\nSCORE\n" + player.GetVar("score") + "\n\nLINES\n" + player.GetVar("lines_cleared") + "\n\nLEVEL\n" + (player.GetVar("level") + 1);
        player.SendGameText(-0.666, -0.375, CHAN_STATS, "255 255 255", stats);
    }

    function OnGameOver(victory)
    {
        if(player.GetVar("score") > CookieUtil.Get(player, "highscore_marathon"))
            CookieUtil.Set(player, "highscore_marathon", player.GetVar("score"));
    }
}

Gamemodes[GAMEMODE.FORTYLINE] <- class extends Gamemode
{
    allow_increment_level = false;

    ticks_elapsed = 0;
    lines_remaining = 40;

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

    function DrawHUDStats()
    {
        local stats = "TOP TIME\n" + FormatTime(TicksToTime(CookieUtil.Get(player, "hiscore_40lines"))) + "\n\nTIME\n" + FormatTime(TicksToTime(ticks_elapsed)) + "\n\nLINES\n" + lines_remaining;
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

        if(ticks_elapsed < CookieUtil.Get(player, "hiscore_40lines"))
           CookieUtil.Set(player, "hiscore_40lines", ticks_elapsed);
    }
}

Gamemodes[GAMEMODE.ULTRA] <- class extends Gamemode
{
    allow_increment_level = false;

    ticks_remaining = 7920; //2 min

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

    function DrawHUDStats()
    {
        local stats = "TIME LEFT\n" + FormatTime(TicksToTime(ticks_remaining)) + "\n\nHISCORE\n" + CookieUtil.Get(player, "hiscore_ultra") + "\n\nSCORE\n" + player.GetVar("score");
        player.SendGameText(-0.661, -0.475, CHAN_STATS, "255 255 255", stats);
    }

    function OnGameOver(victory)
    {
        if(!victory)
            return;

        if(player.GetVar("score") > CookieUtil.Get(player, "hiscore_ultra"))
            CookieUtil.Set(player, "hiscore_ultra", player.GetVar("score"));
    }
}