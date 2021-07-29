
local S = core.get_translator(cleaner.modname)


--- Cleans duplicate entries from indexed table.
--
--  @local
--  @function clean_duplicates
--  @tparam table t
--  @treturn table
local function clean_duplicates(t)
	local tmp = {}
	for _, v in ipairs(t) do
		tmp[v] = true
	end

	t = {}
	for k in pairs(tmp) do
		table.insert(t, k)
	end

	return t
end

local world_file = core.get_worldpath() .. "/cleaner.json"

local function get_world_data()
	local wdata = {}
	local buffer = io.open(world_file, "r")
	if buffer then
		wdata = core.parse_json(buffer:read("*a"))
		buffer:close()
	end

	local rem_types = {"entities", "nodes", "ores",}
	local rep_types = {"items", "nodes",}

	for _, t in ipairs(rem_types) do
		wdata[t] = wdata[t] or {}
		wdata[t].remove = wdata[t].remove or {}
	end

	for _, t in ipairs(rep_types) do
		wdata[t] = wdata[t] or {}
		wdata[t].replace = wdata[t].replace or {}
	end

	return wdata
end

local function update_world_data(t, data)
	local wdata = get_world_data()
	if t and data then
		wdata[t].remove = data.remove
		wdata[t].replace = data.replace
	end

	local json_string = core.write_json(wdata, true):gsub("\"remove\" : null", "\"remove\" : []")
		:gsub("\"replace\" : null", "\"replace\" : {}")

	local buffer = io.open(world_file, "w")
	if buffer then
		buffer:write(json_string)
		buffer:close()

		return true
	end

	return false
end

local tool = {
	modes = {
		erase = true,
		write = true,
		swap = true,
	},
	format_name = function(self, stack)
		local iname = stack:get_name()
		if iname == "cleaner:pencil_1" then
			iname = "cleaner:pencil"
		end

		return iname
	end,

	set_mode = function(self, stack, mode, pname)
		local iname = self:format_name(stack)

		if not self.modes[mode] then
			if pname then
				core.chat_send_player(pname, iname .. ": " .. S("unknown mode: @1", mode))
			end
			cleaner.log("warning", iname .. ": unknown mode: " .. mode)
			return stack
		end

		local imeta = stack:get_meta()
		imeta:set_string("mode", mode)

		if pname then
			core.chat_send_player(pname, iname .. ": "
				.. S("mode set to: @1", imeta:get_string("mode")))
		end

		local new_stack
		if mode == "erase" then
			new_stack = ItemStack("cleaner:pencil_1")
		else
			new_stack = ItemStack("cleaner:pencil")
		end

		local new_meta = new_stack:get_meta()
		new_meta:from_table(imeta:to_table())

		return new_stack
	end,

	set_node = function(self, stack, node, pname)
		local imeta = stack:get_meta()
		imeta:set_string("node", node)

		if pname then
			core.chat_send_player(pname, stack:get_name() .. ": "
				.. S("node set to: @1", imeta:get_string("node")))
		end

		return stack
	end,
}

tool.on_use = function(stack, user, pointed_thing)
	if not user:is_player() then return end

	local pname = user:get_player_name()
	if not core.get_player_privs(pname).server then
		core.chat_send_player(pname, S("You do not have permission to use this item. Missing privs: server"))
		return stack
	end

	if sound_handle then
		core.sound_stop(sound_handle)
		sound_handle = nil
	end

	if pointed_thing.type == "node" then
		local npos = core.get_pointed_thing_position(pointed_thing)
		local imeta = stack:get_meta()
		local mode = imeta:get_string("mode")
		local new_node_name = imeta:get_string("node")

		if mode == "erase" then
			core.remove_node(npos)
			sound_handle = core.sound_play("cleaner_pencil_erase", {object=user})
			return stack
		elseif core.registered_nodes[new_node_name] then
			if mode == "swap" then
				core.swap_node(npos, {name=new_node_name})
				sound_handle = core.sound_play("cleaner_pencil_write", {object=user})
				return stack
			elseif mode == "write" then
				local node_above = core.get_node_or_nil(pointed_thing.above)
				if not node_above or node_above.name == "air" then
					core.place_node(pointed_thing.above, {name=new_node_name})
					sound_handle = core.sound_play("cleaner_pencil_write", {object=user})
				else
					core.chat_send_player(pname, S("Can't place node there."))
				end

				return stack
			else
				core.chat_send_player(pname, S("Unknown mode: @1", mode))
			end
		end

		core.chat_send_player(pname, S("Cannot place unknown node: @1", new_node_name))
		return stack
	end
end

tool.on_secondary_use = function(stack, user, pointed_thing)
	if not user:is_player() then return end

	local pname = user:get_player_name()
	if not core.get_player_privs(pname).server then
		core.chat_send_player(pname, S("You do not have permission to use this item. Missing privs: @1", "server"))
		return stack
	end

	local imeta = stack:get_meta()
	local mode = imeta:get_string("mode")
	if mode == "erase" or mode == "" then
		mode = "write"
	elseif mode == "write" then
		mode = "swap"
	else
		mode = "erase"
	end

	return tool:set_mode(stack, mode, pname)
end

tool.on_place = function(stack, placer, pointed_thing)
	if not placer:is_player() then return end

	local pname = placer:get_player_name()
	if not core.get_player_privs(pname).server then
		core.chat_send_player(pname, S("You do not have permission to use this item. Missing privs: @1", "server"))
		return stack
	end

	if pointed_thing.type == "node" then
		local node = core.get_node_or_nil(core.get_pointed_thing_position(pointed_thing))
		if node then
			stack = tool:set_node(stack, node.name, pname)
		end
	end

	return stack
end


return {
	clean_duplicates = clean_duplicates,
	get_world_data = get_world_data,
	update_world_data = update_world_data,
	tool = tool,
}
