// BUTTONS
::CTFPlayer.GetButtons <- function()
{
    return GetPropInt(this, "m_nButtons");
}

::CTFPlayer.IsHoldingButton <- function(button)
{
    return GetButtons() & button;
}

::CTFPlayer.WasButtonJustPressed <- function(button)
{
    return !(GetVar("last_buttons") & button) && GetButtons() & button;
}

// VARIABLES
::CTFPlayer.SetVar <- function(name, value)
{
    local playerVars = this.GetScriptScope();
    playerVars[name] <- value;
    return value;
}

::CTFPlayer.GetVar <- function(name)
{
    local playerVars = this.GetScriptScope();
    return playerVars[name];
}

::CTFPlayer.AddVar <- function(name, addValue)
{
    local playerVars = this.GetScriptScope();
    local value = playerVars[name];
    return playerVars[name] <- value + addValue;
}

::CTFPlayer.SubtractVar <- function(name, subtractValue)
{
    local playerVars = this.GetScriptScope();
    local value = playerVars[name];
    return playerVars[name] <- value - subtractValue;
}

::ignored_print_vars <- ["__vname", "__vrefs", "self",
"score", "last_buttons", "lines_cleared", "level", "can_switch_hold",
"board_blocks", "next_tetromino_model_array", "active_tetromino", "ghost_tetromino", "hold_tetromino_cluster_model",
"grab_bag", "game_paused", "game_active", "lines_to_clear", "hold_tetromino_shape"];

::CTFPlayer.DebugGetAllVars <- function()
{
    local playerVars = this.GetScriptScope();
    local string = "";
    foreach(variable, value in playerVars)
    {
        if(ignored_print_vars.find(variable) != null)
            continue;

        string += variable + ":" + value + "\n"
    }
    return string;
}

::CTFPlayer.GetAccountID <- function()
{
    try
    {
        return split(GetPropString(this, "m_szNetworkIDString"), ":")[2].tointeger();
    }
    catch (exception)
    {
        return null;
    }
}

::CTFPlayer.PlaySoundForPlayer <- function(data)
{
    local base_table = {entity = this, filter_type = RECIPIENT_FILTER_SINGLE_PLAYER};

    if(safeget(data, "sound_name", null))
        PrecacheSound(safeget(data, "sound_name", null));

    EmitSoundEx(combinetables(data, base_table));
}

::CTFPlayer.SendChat <- function(message)
{
    ClientPrint(this, HUD_PRINTTALK, message);
}

::CreateInstancedProp <- function(client, model)
{
    PrecacheModel(model);
    local prop = CreateByClassname("obj_teleporter"); // not using SpawnEntityFromTable as that creates spawning noises
    prop.DispatchSpawn();

    prop.AddEFlags(EFL_NO_THINK_FUNCTION); // prevents the entity from disappearing
    prop.SetSolid(SOLID_NONE);
    prop.SetMoveType(MOVETYPE_NOCLIP, MOVECOLLIDE_DEFAULT);
    prop.SetCollisionGroup(COLLISION_GROUP_NONE);
    SetPropBool(prop, "m_bPlacing", true);
    SetPropInt(prop, "m_fObjectFlags", 2); // sets "attachment" flag, prevents entity being snapped to player feet
    SetPropEntity(prop, "m_hBuilder", client);
    SetPropEntity(prop, "m_hOwnerEntity", client);

    prop.SetModel(model);
    prop.KeyValueFromInt("disableshadows", 1);

    return prop;
}

::CTFPlayer.RemoveInstancedProps <- function()
{
    local entity = null
    while(entity = FindByClassname(entity, "obj_teleporter"))
    {
        if(GetPropEntity(entity, "m_hBuilder") == this)
            entity.Destroy();
    }
}

::CTFPlayer.RemoveAllWeapons <- function()
{
    for (local i = 0; i < 8; i++)
    {
        local weapon = GetPropEntityArray(this, "m_hMyWeapons", i);
        if (!weapon) continue;
        weapon.Kill();
    }
}

::CTFPlayer.RemoveAllWearables <- function()
{
    local wearables_to_destroy = [];
    for (local wearable = this.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer())
    {
        if (wearable.GetClassname() != "tf_wearable")
            continue;
        wearables_to_destroy.append(wearable);
    }
    foreach(wearable in wearables_to_destroy)
        wearable.Destroy();
}

::CTFPlayer.RemoveAllViewmodels <- function()
{
    local entity = null
    while(entity = FindByClassname(entity, "tf_viewmodel"))
    {
        if(GetPropEntity(entity, "m_hOwner") == this)
            entity.Destroy();
    }
}

::ConstructTwoDimArray <- function(size1, size2, default_value)
{
	local return_array = array(size1);
	for(local i = 0; i < size1; i++)
		return_array[i] = array(size2, default_value);

	return return_array;
}

::VLerp <- function(a,b,t)
{
    return (a + (b - a) * t)
}