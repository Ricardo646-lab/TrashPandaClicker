extends Node

# Autoload "Poki": tells the Poki SDK when the player is playing.
# gameLoadingFinished is sent by the HTML shell (full-size.html) once the
# engine has started. The game has no ads.

var _playing := false


func _sdk():
	if not OS.has_feature("web"):
		return null
	var sdk = get_node_or_null("/root/PokiSDK")
	if sdk == null or not sdk.has_method("gameplayStart") or sdk.get("sdk_handle") == null:
		return null
	return sdk


# Main calls this every frame; the SDK is only told when it changes:
# gameplayStart after PLAY and when a menu closes, gameplayStop when a
# menu (shop or popup) opens.
func set_playing(on: bool) -> void:
	if on == _playing:
		return
	_playing = on
	var sdk = _sdk()
	if sdk:
		if on:
			sdk.gameplayStart()
		else:
			sdk.gameplayStop()

