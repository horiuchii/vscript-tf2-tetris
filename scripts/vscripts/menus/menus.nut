::menus <- {};

enum MENU {
    MainMenu
    Singleplayer
    HeadToHead
    Settings

    Pause
    GameOver
}

class Menu
{
    title = "";
    items = {};
    parent_menu = null;
    parent_menuitem = null;
}

class MenuItem
{
    title = "";

    function GenerateDesc(player)
    {
        return "\n\n\n";
    }

    function OnSelected(player){}
}

::GetMenu <- function(menu_index)
{
    return menus[menu_index];
}

IncludeScript(projectDir+"menus/pause_menu.nut", this);
IncludeScript(projectDir+"menus/gameover_menu.nut", this);

IncludeScript(projectDir+"menus/main_menu.nut", this);
IncludeScript(projectDir+"menus/soloplay_menu.nut", this);

::CTFPlayer.HandleCurrentMenu <- function()
{
    // Navigate Menu
    if(WasButtonJustPressed(IN_FORWARD) || WasButtonJustPressed(IN_BACK))
    {
        local length = GetMenu(GetVar("menu_index")).items.len() - 1;
        local new_loc = GetVar("selected_option") + (WasButtonJustPressed(IN_FORWARD) ? -1 : 1);

        if(new_loc < 0)
            new_loc = length;
        else if(new_loc > length)
            new_loc = 0;

        SetVar("selected_option", new_loc);

        PlaySoundForPlayer({sound_name = "tetromino_move.mp3"});
    }

    // Select Menu Item
    if(WasButtonJustPressed(IN_ATTACK) || WasButtonJustPressed(IN_JUMP))
    {
        GetMenu(GetVar("menu_index")).items[GetVar("selected_option")].OnSelected(this);
        PlaySoundForPlayer({sound_name = "tetromino_rotate.mp3"});
    }

    // Return To Previous Menu
    if(WasButtonJustPressed(IN_ATTACK2))
    {
        GoUpMenuDir();
    }

    if(GetVar("menu_index") != null)
        GenerateMenuText();
}

CTFPlayer.GoUpMenuDir <- function(playsound = true)
{
    local menu = GetMenu(GetVar("menu_index"));

    if(menu.parent_menu == null || menu.parent_menuitem == null)
        return;

    SetVar("selected_option", menu.parent_menuitem);
    SetVar("menu_index", menu.parent_menu);

    if(playsound)
        PlaySoundForPlayer({sound_name = "tetromino_harddrop.mp3"});
}

CTFPlayer.GenerateMenuText <- function()
{
    local current_menu = GetMenu(GetVar("menu_index"));

    local previous_title = current_menu.parent_menu != null ? GetMenu(current_menu.parent_menu).title + " > " : "";
    local message = previous_title + current_menu.title + "\n\n";
    local menu_size = current_menu.items.len();
    local option_count = 2;
    for(local i = GetVar("selected_option") - option_count; i < GetVar("selected_option") + (option_count + 1); i++)
    {
        local index = i;

        if(index == -1 && menu_size > option_count)
        {
            message += "▲\n";
            continue;
        }
        if(index == menu_size && menu_size > option_count)
        {
            message += "▼\n";
            continue;
        }
        if(index < 0 || index > menu_size - 1)
        {
            message += "\n";
            continue;
        }

        message += current_menu.items[index].title;
        message += "\n";
    }

    local description = current_menu.items[GetVar("selected_option")].GenerateDesc(this);

    message += "\n" + description + "";
    SendGameText(-1, 0.3, CHAN_MENU, "255 255 255", message);
    SendGameText(0.666, 0.75, CHAN_INSTRUCTIONS, "255 255 255", "Game Controls:\n[FIRE / ALT-FIRE] Rotate\n[STRAFE] Move\n[FORWARD] Hold\n[BACK] Soft Drop\n[JUMP] Hard Drop\n[SCOREBOARD] Pause\n[RELOAD] Restart\n\nMenu Controls:\n[FIRE / JUMP] Confirm\n[ALT-FIRE] Return\n[FORWARD/BACK] Move");
    SendGameText(0.666, 0.5, 2, "255 255 255", "");
    SendGameText(0.666, 0.3, 3, "255 255 255", "");
    SendGameText(0.666, 0, 4, "255 255 255", "");
}