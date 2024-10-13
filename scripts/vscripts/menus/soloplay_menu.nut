menus[MENU.Singleplayer] <- class extends Menu
{
    title = "Solo Play";
    items = {};
    parent_menu = MENU.MainMenu
    parent_menuitem = MAINMENU_ITEMS.Singleplayer
}();

::GenerateGamemodeMenuItems <- function()
{
    foreach(i, _gamemode in Gamemodes)
    {
        menus[MENU.Singleplayer].items[i] <- (class extends MenuItem
        {
            gamemode = _gamemode;
            title = _gamemode.name;

            function GenerateDesc(player)
            {
                return gamemode.GenerateDesc(player);
            }

            function OnSelected(player)
            {
                player.SetVar("gamemode", gamemode(player));
                player.SetVar("menu_index", null);
                player.GetVar("gamemode").OnRoundReset();
            }
        })
    }
}
GenerateGamemodeMenuItems();