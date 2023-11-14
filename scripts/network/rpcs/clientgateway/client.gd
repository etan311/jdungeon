extends Node

class_name ClientRPC

signal account_created(response: Dictionary)
signal authenticated(response: bool)
signal server_info_received(response: Dictionary)

signal player_logged_in(id: int, username: String)

@rpc("call_remote", "any_peer", "reliable") func create_account(username, password):
	if not C.is_server():
		return

	GodotLogger.info("Creating account for user=[%s]" % username)
	var id: int = multiplayer.get_remote_sender_id()

	var create_account_result: Dictionary = C.database.create_account(username, password)
	if create_account_result["result"]:
		create_account_response.rpc_id(id, false, "Account created")
	else:
		create_account_response.rpc_id(id, true, create_account_result["error"])


@rpc("call_remote", "authority", "reliable")
func create_account_response(error: bool, reason: String = ""):
	account_created.emit({"error": error, "reason": reason})


@rpc("call_remote", "any_peer", "reliable") func authenticate(username, password):
	if not C.is_server():
		return

	GodotLogger.info("Authenticating user=[%s]" % username)
	var id = multiplayer.get_remote_sender_id()

	var res = C.database.authenticate_user(username, password)

	var user: C.User = C.users[id]
	user.logged_in = res

	if res:
		GodotLogger.info("Player=[%s] successfully logged in" % username)
		user.username = username
		player_logged_in.emit(id, username)

	authentication_response.rpc_id(id, res)


@rpc("call_remote", "authority", "reliable") func authentication_response(response: bool):
	authenticated.emit(response)


@rpc("call_remote", "any_peer", "reliable") func get_server():
	if not C.is_server():
		return

	var id = multiplayer.get_remote_sender_id()

	# Only allow logged in players
	if not C.is_user_logged_in(id):
		return

	var user: C.User = C.get_user_by_id(id)
	if user == null:
		GodotLogger.warn("Could not find user with id=%d" % id)
		return

	var data: Dictionary = C.database.load_player_data(user.username)
	if data.is_empty():
		GodotLogger.info("User=[%s] does not have peristent data" % user.username)
	else:
		# print(data)
		pass

	# Send coockie to server
	var cookie: String = J.uuid_util.v4()

	var server_name: String = "World"

	var server: S.Server = S.get_server_by_name(server_name)
	if server == null:
		GodotLogger.warn("Could not find server=[%s]" % server_name)
		get_server_response.rpc_id(id, true, "World", "", 0, "")
		return

	# Register the user on the server side
	GodotLogger.info("Registering user=[%s] on server=[%s]" % [user.username, server.name])
	S.server_rpc.register_user.rpc_id(server.peer_id, user.username, cookie)

	# Todo: fetch this from database
	GodotLogger.info("Sending server=[%s] data to user=[%s]" % [server.name, user.username])
	get_server_response.rpc_id(id, false, server.name, server.address, server.port, cookie)


@rpc("call_remote", "authority", "reliable") func get_server_response(
	error: bool, server_name: String, address: String, port: int, cookie: String
):
	server_info_received.emit(
		{"error": error, "name": server_name, "address": address, "port": port, "cookie": cookie}
	)
