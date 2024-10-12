menus[MENU.Pause] <- class extends Menu
{
    title = "Game Paused";
    items = {};
}();

enum PAUSEMENU_ITEMS
{
    Resume
    Restart
    Quit
}

menus[MENU.Pause].items[PAUSEMENU_ITEMS.Resume] <- class extends MenuItem
{
    title = "Resume"

    function OnSelected(player)
    {
        player.SetVar("menu_index", null);
    }
}();

menus[MENU.Pause].items[PAUSEMENU_ITEMS.Restart] <- class extends MenuItem
{
    title = "Restart"

    function OnSelected(player)
    {
        player.SetVar("menu_index", null);
        player.GetVar("gamemode").OnRoundReset();
    }
}();

menus[MENU.Pause].items[PAUSEMENU_ITEMS.Quit] <- class extends MenuItem
{
    title = "Return To Main Menu"

    function OnSelected(player)
    {
        player.RemoveInstancedProps();
        player.SetVar("menu_index", MENU.MainMenu);
        player.SetVar("selected_option", 0);
        player.SetVar("gamemode", null);
    }
}();