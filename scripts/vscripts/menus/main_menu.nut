menus[MENU.MainMenu] <- class extends Menu
{
    title = "Main Menu";
    items = {};
}();

enum MAINMENU_ITEMS
{
    Singleplayer
    HeadToHead
    Settings
}

menus[MENU.MainMenu].items[MAINMENU_ITEMS.Singleplayer] <- class extends MenuItem
{
    title = "Solo Play"

    function GenerateDesc(player)
    {
        return "\nChoose a variety of solo\ngamemodes to play tetris in.\n";
    }

    function OnSelected(player)
    {
        player.SetVar("menu_index", MENU.Singleplayer);
        player.SetVar("selected_option", 0);
    }
}();

menus[MENU.MainMenu].items[MAINMENU_ITEMS.HeadToHead] <- class extends MenuItem
{
    title = "Head-To-Head"

    function GenerateDesc(player)
    {
        return "\nCompete against others to\nsee who is the tetris master.\nComing Soon...";
    }

    function OnSelected(player)
    {
        //player.SetVar("menu_index", MENU.HeadToHead);
        //player.SetVar("selected_option", 0);
    }
}();

menus[MENU.MainMenu].items[MAINMENU_ITEMS.Settings] <- class extends MenuItem
{
    title = "Settings"

    function GenerateDesc(player)
    {
        return "\nAdjust various aspects\nabout your tetris.\nComing Soon...";
    }

    function OnSelected(player)
    {
        //player.SetVar("menu_index", MENU.Settings);
        //player.SetVar("selected_option", 0);
    }
}();