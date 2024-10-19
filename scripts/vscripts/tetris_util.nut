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

::ignored_print_vars <- ["__vname", "__vrefs"];

::CTFPlayer.DrawDebugVars <- function()
{
    local playerVars = this.GetScriptScope();
    local line_offset = 0;
    foreach(variable, value in playerVars)
    {
        if(variable == null)
            continue;

        if(ignored_print_vars.find(variable) != null)
            continue;

        if(typeof value == "array")
            value = ArrayToStr(value)

        DebugDrawScreenTextLine(
            0.05, 0.67, line_offset++,
            variable + ": " + value,
            255, 255, 255, 255, 0.03
        );
    }
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

::CTFPlayer.PlaySoundForPlayer <- function(data, delay = 0)
{
    local base_table = {entity = this, filter_type = RECIPIENT_FILTER_SINGLE_PLAYER};

    if(safeget(data, "sound_name", null))
        PrecacheSound(safeget(data, "sound_name", null));

    if(delay)
        RunWithDelay(delay, function(){EmitSoundEx(combinetables(data, base_table));})
    else
        EmitSoundEx(combinetables(data, base_table));
}

::CTFPlayer.SendChat <- function(message)
{
    ClientPrint(this, HUD_PRINTTALK, message);
}

::CTFPlayer.CreateInstancedProp <- function(model)
{
    PrecacheModel(model);
    local prop = CreateByClassname("obj_teleporter"); // not using SpawnEntityFromTable as that creates spawning noises
    prop.DispatchSpawn();

    prop.AddEFlags(EFL_NO_THINK_FUNCTION); // prevents the entity from disappearing
    SetPropBool(prop, "m_bPlacing", true);
    SetPropInt(prop, "m_fObjectFlags", 2); // sets "attachment" flag, prevents entity being snapped to player feet
    SetPropEntity(prop, "m_hBuilder", this);

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
        if(!weapon) continue;
        weapon.Kill();
    }
}

::CTFPlayer.RemoveAllWearables <- function()
{
    local wearables_to_destroy = [];
    for (local wearable = this.FirstMoveChild(); wearable != null; wearable = wearable.NextMovePeer())
    {
        if(wearable.GetClassname() != "tf_wearable")
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

::ArrayToStr <- function(value)
{
    local new_value = "[";
    foreach(i, array_var in value)
    {
        new_value += array_var + (i == value.len() - 1 ? "" : ", ");
    }
    new_value += "]";
    return new_value;
}

::round <- function(val, decimalPoints)
{
	local f = pow(10, decimalPoints) * 1.0;
	local newVal = val * f;
	newVal = floor(newVal + 0.5);
	newVal = (newVal * 1.0) / f;

	return newVal;
}

::TicksToTime <- function(ticks)
{
    return ticks * TICKRATE_TIME;
}

::FormatTime <- function(input_time)
{
	local input_time_type = type(input_time);

	if(input_time_type == "integer")
	{
		local Min = input_time / 60;
		local Sec = input_time - (Min * 60);
		local SecString = format("%s%i", Sec < 10 ? "0" : "", Sec);
		return (Min + ":" + SecString).tostring();
	}

	if(input_time_type == "float")
	{
		local timedecimal = split((round(input_time - input_time.tointeger(), 3)).tostring(), ".");
		local Min = input_time.tointeger() / 60;
		local Sec = input_time.tointeger() - (Min * 60);
		local SecString = format("%s%i", Sec < 10 ? "0" : "", Sec);
		return (Min + ":" + SecString + "." + (timedecimal.len() == 1 ? "000" : timedecimal[1].len() == 1 ? timedecimal[1].tostring() + "0" : timedecimal[1].tostring())).tostring();
	}

	return input_time.tostring();
}