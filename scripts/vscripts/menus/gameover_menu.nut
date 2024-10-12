menus[MENU.GameOver] <- class extends Menu
{
    title = "Game Over";
    items = {};
}();

enum GAMEOVER_ITEMS
{
    Restart
    Quit
}

menus[MENU.GameOver].items[GAMEOVER_ITEMS.Restart] <- class extends MenuItem
{
    title = "Restart"

    function OnSelected(player)
    {
        player.SetVar("menu_index", null);
        player.GetVar("gamemode").OnRoundReset();
    }
}();

menus[MENU.GameOver].items[GAMEOVER_ITEMS.Quit] <- class extends MenuItem
{
    title = "Return To Main Menu"

    function OnSelected(player)
    {
        player.RemoveInstancedProps();
        player.SetVar("menu_index", MENU.MainMenu);
        player.SetVar("gamemode", null);
        player.SetVar("selected_option", 0);
    }
}();