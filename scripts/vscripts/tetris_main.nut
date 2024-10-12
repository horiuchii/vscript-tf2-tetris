::DEBUG <- false;

::projectDir <- ""
IncludeScript(projectDir+"/__lizardlib/_lizardlib.nut", this);
IncludeScript(projectDir+"tetris_const.nut", this);
IncludeScript(projectDir+"tetris_util.nut", this);
IncludeScript(projectDir+"block_util.nut", this);
IncludeScript(projectDir+"tetris_cookies.nut", this);
IncludeScript(projectDir+"tetris_hud.nut", this);
IncludeScript(projectDir+"menus/menus.nut", this);
IncludeScript(projectDir+"tetris_gamemodes.nut", this);
IncludeScript(projectDir+"tetris_classes.nut", this);
IncludeScript(projectDir+"tetris_player.nut", this);

Convars.SetValue("mp_waitingforplayers_cancel", 1);
Convars.SetValue("mp_forceautoteam", 1);
Convars.SetValue("mp_humans_must_join_team", "red");
Convars.SetValue("mp_allowspectators", 0);
Convars.SetValue("tf_dropped_weapon_lifetime", 0);
Convars.SetValue("tf_force_holidays_off", 1);
Convars.SetValue("sv_alltalk", 1);

function OnPostSpawn()
{
    FireListeners("setup_start", {});
}

function TickFrame()
{
    FireListeners("tick_frame", {});
    return -1;
}

tf_gamerules.ValidateScriptScope();
tf_gamerules.GetScriptScope().Tick <- function()
{
    FireListeners("tick", {});
    return 0.1;
}
AddThinkToEnt(tf_gamerules, "Tick");

tf_player_manager.ValidateScriptScope();
tf_player_manager.GetScriptScope().Tick <- function()
{
    FireListeners("tick_player_manager", {});
    return -1;
}
AddThinkToEnt(tf_player_manager, "Tick");

OnGameEvent("player_say", function(params)
{
    if(params.text == "/toggle_debug")
        DEBUG = !DEBUG;
})