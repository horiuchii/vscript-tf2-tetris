class Cookies
{
    PlayerData = {}
    PlayerBannedSaving = {}
    loaded_cookies = false

    Table =
    {
        ["highscore_marathon"] =
        {
            default_value = 0
        },
        ["hiscore_40lines"] =
        {
            default_value = 39534 //9:59 in ticks
        },
        ["hiscore_ultra"] =
        {
            default_value = 0
        }
    }
}
::Cookies <- Cookies();

class CookieUtil
{
    SAVE_DIR = "tetris/"
    SAVE_EXTENSION = ".sav"

    function Get(player, cookie)
    {
        return Cookies.PlayerData[player.entindex()][cookie];
    }

    function Set(player, cookie, value, save = true)
    {
        Cookies.PlayerData[player.entindex()][cookie] <- value;

        if(save)
        {
            SetPersistentVar("player_cookies", Cookies.PlayerData);
            SavePlayerData(player);
        }

        return Cookies.PlayerData[player.entindex()][cookie];
    }

    function Add(player, cookie, value, save = true)
    {
        Cookies.PlayerData[player.entindex()][cookie] <- Cookies.PlayerData[player.entindex()][cookie] + value;

        if(save)
        {
            SetPersistentVar("player_cookies", Cookies.PlayerData);
            SavePlayerData(player);
        }

        return Cookies.PlayerData[player.entindex()][cookie];
    }

    function Reset(player)
    {
        local default_cookies = {};
        foreach (name, cookie in Cookies.Table)
        {
            default_cookies[name] <- cookie.default_value;
        }

        Cookies.PlayerData[player.entindex()] <- default_cookies;

        SetPersistentVar("player_cookies", Cookies.PlayerData);
    }

    function CreateCache(player)
    {
        Reset(player);

        if(!player.GetAccountID())
        {
            Cookies.PlayerBannedSaving[player.GetUserID()] <- true;
            player.SendChat("Something went wrong when trying to get your cookies. Rejoining may fix.");
            return;
        }

        if(!Cookies.loaded_cookies)
        {
            LoadPersistentCookies();
        }

        LoadPlayerData(player)
    }

    function LoadPersistentCookies()
    {
        local cookies_to_load = GetPersistentVar("player_cookies", null);
        if(cookies_to_load)
            Cookies.PlayerData = cookies_to_load;

        Cookies.loaded_cookies = true;
    }

    function SavePlayerData(player)
    {
        if(player.GetUserID() in Cookies.PlayerBannedSaving)
        {
            player.SendChat("Refusing to save your cookies due to a previous error. Rejoining may fix.");
            return;
        }

        local save = "";

        foreach (name, cookie in Cookies.Table)
        {
            local cookie_value = CookieUtil.Get(player, name);

            switch(type(cookie_value))
            {
                case "string": cookie_value = cookie_value.tostring(); break;
                case "bool":
                case "integer": cookie_value = cookie_value.tointeger(); break;
            }

            save += name + "," + cookie_value + "\n"
        }

        StringToFile(SAVE_DIR + player.GetAccountID() + SAVE_EXTENSION, save);
    }

    function LoadPlayerData(player)
    {
        if(player.GetUserID() in Cookies.PlayerBannedSaving)
        {
            player.SendChat("Refusing to load your cookies due to a previous error. Rejoining may fix.");
            return;
        }

        local save = FileToString(SAVE_DIR + player.GetAccountID() + SAVE_EXTENSION);

        if(save == null)
            return false;

        try
        {
            local split_save = split(save, "\n", true);
            foreach (save_entry in split_save)
            {
                local entry_array = split(save_entry, ",");
                local key_buffer = entry_array[0];
                local value_buffer = entry_array[1];
                if(key_buffer in Cookies.Table)
                {
                    switch(type(Cookies.Table[key_buffer].default_value))
                    {
                        case "string": value_buffer = value_buffer.tostring(); break;
                        case "integer": value_buffer = value_buffer.tointeger(); break;
                    }
                    CookieUtil.Set(player, key_buffer, value_buffer, false);
                }
            }

            SetPersistentVar("player_cookies", Cookies.PlayerData);
            return true;
        }
        catch(exception)
        {
            player.SendChat("\x07" + "FF0000" + "Your cookies failed to load. Please alert a server admin and provide the text below.");
            player.SendChat("\x07" + "FFA500" + "Save: " + "tf/scriptdata/" + SAVE_DIR + player.GetAccountID() + SAVE_EXTENSION);
            player.SendChat("\x07" + "FFA500" + "Error: " + exception);
        }
    }

    function MakeGenericCookieString(player, cookie)
    {
        local option_setting = Get(player, cookie);
        if(type(option_setting) == "integer" || type(option_setting) == "bool")
            option_setting = option_setting ? "[On]" : "[Off]";
        else
            option_setting = "[" + option_setting + "]";

        return option_setting + "\n";
    }
}
::CookieUtil <- CookieUtil();