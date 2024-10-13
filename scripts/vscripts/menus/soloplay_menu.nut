menus[MENU.Singleplayer] <- class extends Menu
{
    title = "Solo Play";
    items = {};
    parent_menu = MENU.MainMenu
    parent_menuitem = MAINMENU_ITEMS.Singleplayer
}();

enum SINGLEPLAYER_MENU_ITEMS
{
    Marathon
    FortyLine
    Ultra
    //Mission
}

menus[MENU.Singleplayer].items[SINGLEPLAYER_MENU_ITEMS.Marathon] <- class extends MenuItem
{
    title = "Marathon"

    function GenerateDesc(player)
    {
        return "Highscore: " + CookieUtil.Get(player, "highscore_marathon") + "\n\nSee how long you can last\nin an endless tetris!";
    }

    function OnSelected(player)
    {
        player.SetVar("gamemode", Gamemodes[GAMEMODE.MARATHON](player));
        player.SetVar("menu_index", null);
        player.GetVar("gamemode").OnRoundReset();
    }
}();

menus[MENU.Singleplayer].items[SINGLEPLAYER_MENU_ITEMS.FortyLine] <- class extends MenuItem
{
    title = "40 Line"

    function GenerateDesc(player)
    {
        return "Best Time: " + FormatTime(TicksToTime(CookieUtil.Get(player, "hiscore_40lines"))) + "\n\nRace to clear 40 lines\nas fast as you can!";
    }

    function OnSelected(player)
    {
        player.SetVar("gamemode", Gamemodes[GAMEMODE.FORTYLINE](player));
        player.SetVar("menu_index", null);
        player.GetVar("gamemode").OnRoundReset();
    }
}();

menus[MENU.Singleplayer].items[SINGLEPLAYER_MENU_ITEMS.Ultra] <- class extends MenuItem
{
    title = "Ultra"

    function GenerateDesc(player)
    {
        return "Highscore: " + CookieUtil.Get(player, "hiscore_ultra") + "\n\nScore as many points as\nyou can within 2 minutes!";
    }

    function OnSelected(player)
    {
        player.SetVar("gamemode", Gamemodes[GAMEMODE.ULTRA](player));
        player.SetVar("menu_index", null);
        player.GetVar("gamemode").OnRoundReset();
    }
}();

// menus[MENU.Singleplayer].items[SINGLEPLAYER_MENU_ITEMS.Mission] <- class extends MenuItem
// {
//     title = "Mission"

//     function GenerateDesc(player)
//     {
//         return "Highscore: " + CookieUtil.Get(player, "hiscore_mission") + "\n\nComplete as many missions as\nyou can under a strict time limit!";
//     }

//     function OnSelected(player)
//     {
        // player.SetVar("gamemode", Gamemodes[GAMEMODE.MISSION](player));
        // player.SetVar("menu_index", null);
        // player.GetVar("gamemode").OnRoundReset();
//     }
// }();