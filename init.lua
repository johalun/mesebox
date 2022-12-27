-- Clamp function
local function clamp(val, val_min, val_max)
	return math.min(math.max(val, val_min), val_max)
end

-- Box width not advertised in settings.txt but may be desirable for games/servers.
local box_width_from_settings = tonumber(minetest.settings:get("mesebox_box_width")) or 8
local box_size_from_settings = tonumber(minetest.settings:get("mesebox_box_size")) or (box_width_from_settings * 3)

-- Mesebox
local mesebox = {
	-- Clamped to tested values. Probably works beyond.
	box_width = clamp(box_width_from_settings, 1, 10),
	box_size  = clamp(box_size_from_settings, 1, 50)
}

mesebox.open_meseboxs = {}
mesebox.variants = {
	white = "White Mesebox",
	black = "Black Mesebox",
	red = "Red Mesebox",
	blue = "Blue Mesebox",
	green = "Green Mesebox",
	yellow = "Yellow Mesebox",
	orange = "Orange Mesebox",
	violet = "Violet Mesebox",
}

local pipeworks_enabled = minetest.get_modpath("pipeworks") ~= nil

function mesebox.get_mesebox_formspec(pos)
	local meta = minetest.get_meta(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local alias = meta:get_string("alias") and meta:get_string("alias") or meta:get_string("description")
	local box_size = meta:get_inventory():get_size("main") or mesebox.box_size
	local box_width = mesebox.box_width
	local player_inv_width = 8
	local num_rows = math.ceil(box_size / mesebox.box_width)
	local fs_width = math.max(box_width, player_inv_width)
	local formspec = "size[" .. fs_width ..",".. (5.5 + num_rows) .. "]" ..
		"field[0.3,0.1;4,1;alias;;" .. alias  .. "]"..
		"button_exit[4,-0.2;2,1;save;Update Name]"..
		"list[nodemeta:" .. spos .. ";main;0,0.8;" .. box_width .. "," .. num_rows .. ";]" ..
		"label[0,"..tostring(num_rows + 1)..";"..minetest.formspec_escape(minetest.colorize("#fff", "Inventory")).."]"..
		"list[current_player;main;0,"..tostring(num_rows+1.5)..";" .. player_inv_width .. ",1;]"..
		default.get_hotbar_bg(0,num_rows+1.5,player_inv_width,1)..
		"list[current_player;main;0,"..tostring(num_rows+2.7)..";" .. player_inv_width ..",3;8]"..
		default.get_hotbar_bg(0,num_rows+2.7,player_inv_width,3)..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]"
	return formspec
end

function mesebox.mesebox_lid_close(pn)
	local mesebox_open_info = mesebox.open_meseboxs[pn]
	local pos = mesebox_open_info.pos
	local sound = mesebox_open_info.sound
	local swap = mesebox_open_info.swap

	mesebox.open_meseboxs[pn] = nil
	for k, v in pairs(mesebox.open_meseboxs) do
		if v.pos.x == pos.x and v.pos.y == pos.y and v.pos.z == pos.z then
			return true
		end
	end

	local node = minetest.get_node(pos)
	minetest.after(0.2, minetest.swap_node, pos, { name = swap,
			param2 = node.param2 })
	minetest.sound_play(sound, {gain = 0.3, pos = pos,
		max_hear_distance = 10}, true)
end

function mesebox.can_open(pos)
	local dirs = {}
	dirs.n = {x = pos.x, y = pos.y, z = pos.z+1}
	dirs.s = {x = pos.x, y = pos.y, z = pos.z-1}
	dirs.w = {x = pos.x-1, y = pos.y, z = pos.z}
	dirs.e = {x = pos.x+1, y = pos.y, z = pos.z}
	local blocked = 0
	for _,dir in pairs(dirs) do
		local def = minetest.registered_nodes[minetest.get_node(dir).name]
		-- allow ladders, signs, wallmounted things and torches to not obstruct
		if def and (def.drawtype == "airlike" or
			    def.drawtype == "signlike" or
			    def.drawtype == "torchlike" or
			    (def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
		else
			blocked = blocked +1
		end
	end
	return blocked < 4
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "mesebox:mesebox" then
		return
	end
	if not player or not fields.quit then
		return
	end
	local pn = player:get_player_name()

	if not mesebox.open_meseboxs[pn] then
		return
	end

	if fields.alias and fields.alias ~= "" then
		local mesebox_open_info = mesebox.open_meseboxs[pn]
		local pos = mesebox_open_info.pos
		local meta = minetest.get_meta(pos)
		meta:set_string("alias", fields.alias)
		mesebox.update_ratio(meta)
		mesebox.update_infotext(meta)
	end

	mesebox.mesebox_lid_close(pn)
	return true
end)

minetest.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	if mesebox.open_meseboxs[pn] then
		mesebox.mesebox_lid_close(pn)
	end
end)

function mesebox.update_ratio(meta)
	-- update ratio
	local inv = meta:get_inventory()
	local size = inv:get_size("main") 
	local count = 0
	for i = 1, size do
		if not inv:get_stack("main", i):is_empty() then count = count + 1 end
	end
	meta:set_string("ratio", "["..count.."/"..size.."]")
end

function mesebox.update_infotext(meta)
	-- update infotext
	meta:set_string("infotext", meta:get_string("alias") .. " " .. meta:get_string("ratio"))
end

function mesebox.register_mesebox(name, color, desc)
	local def = {}
	def.description = desc
	def.paramtype = "light"
	def.paramtype2 = "facedir"
	def.is_ground_content = false
	def.sunlight_propagates = false
	def.groups = { choppy = 2, oddly_breakable_by_hand = 3, tubedevice = 1,
		       tubedevice_receiver = 1, mesebox = 1 }
	def.sounds = default.node_sound_wood_defaults()
	def.sound_open = "mesebox_open"
	def.sound_close = "mesebox_close"
	def.stack_max = 1
	def.drop = ""

	-- Called every time the item is placed in the world, before 'after_place_node'.
	def.on_construct = function(pos)
		-- Nothing to do here, everything is initialized in
		-- 'after_place_node'
	end

	def.on_rightclick = function(pos, node, clicker)
		-- XXX: The Scanner is currently blocking from opening so don't do this for now.
		-- if not mesebox.can_open(pos) then
		-- 	return
		-- end
		minetest.sound_play(def.sound_open, {gain = 0.5, pos = pos,
						     max_hear_distance = 10}, true)
		minetest.swap_node(pos, { name = name .. "_open",
					  param2 = node.param2 })
		minetest.after(0.2, minetest.show_formspec,
			       clicker:get_player_name(),
			       "mesebox:mesebox", mesebox.get_mesebox_formspec(pos))
		mesebox.open_meseboxs[clicker:get_player_name()] = {
			pos = pos, sound = def.sound_close, swap = name
		}
	end

	def.on_blast = function(pos)
		local drops = {}
		mesebox.get_inventory_drops(pos, "main", drops)
		drops[#drops+1] = name
		minetest.remove_node(pos)
		return drops
	end

	def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local name = player:get_player_name()
		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			return 0
		end

		local group = minetest.get_item_group(stack:get_name(), "mesebox")
		if group == 0 or group == nil then
			return stack:get_count()
		else
			return 0
		end
	end

	def.on_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		mesebox.update_ratio(meta)
		mesebox.update_infotext(meta)
	end

	def.on_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		mesebox.update_ratio(meta)
		mesebox.update_infotext(meta)
	end

	def.tube = {
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("main", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if meta:get_int("splitstacks") == 1 then
				stack = stack:peek_item(1)
			end
			return inv:room_for_item("main", stack)
		end,
		input_inventory = "main",
		connect_sides = {left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1}
	}

	local def_opened = table.copy(def)
	local def_closed = table.copy(def)

	local pipes = ""
	-- XXX: Was gonna use alternative textures for pipeworks but trying a single
	-- more discrete design instead that indicates that pipes are supported.
	-- if pipeworks_enabled then
	-- 	pipes = "_pipes"
	-- end
	def_opened.tiles = {
		-- top, bottom, side, side, side, side
		color.."_mesebox_top"..pipes..".png",
		color.."_mesebox_top"..pipes..".png",
		color.."_mesebox_side_open.png",
		color.."_mesebox_side_open.png",
		color.."_mesebox_side_open.png",
		color.."_mesebox_side_open.png",
	}
	def_closed.tiles = {
		-- top, bottom, side, side, side, side
		color.."_mesebox_top"..pipes..".png",
		color.."_mesebox_top"..pipes..".png",
		color.."_mesebox_side"..pipes..".png",
		color.."_mesebox_side"..pipes..".png",
		color.."_mesebox_side"..pipes..".png",
		color.."_mesebox_side"..pipes..".png",
	}

	def_opened.drop = name
	def_opened.groups.not_in_creative_inventory = 1
	def_opened.groups.not_in_craft_guide = 1

	def_opened.can_dig = function()
		return false
	end

	def_opened.on_blast = function() end

	def_closed.after_place_node = function(pos, placer, itemstack, pointed_thing)
		local nmeta = minetest.get_meta(pos)
		local ninv = nmeta:get_inventory()
		local imeta = itemstack:get_meta()

		local data_str = imeta:get_string("data")
		if data_str == "" then
			-- This Mesebox is placed for the first time, set valid defaults.
			-- Need to re-construct the Node's inventory each time it's placed.
			local box_size = mesebox.box_size
			ninv:set_size("main", box_size)
			nmeta:set_string("alias", desc)
			nmeta:set_string("ratio", "[0/" .. tostring(box_size) .."]")
		else
			local data = minetest.deserialize(data_str)

			-- Need to resize the Node's inventory each time it's placed.
			local size = #data.items
			ninv:set_size("main", size)
			-- Move inventory from ItemStack to Node.
			ninv:set_list("main", data.items)

			-- Copy internal variables.
			for k,v in pairs(data.fields) do
				nmeta:set_string(k,v)
			end
		end
		mesebox.update_infotext(nmeta)

		if pipeworks_enabled then
			pipeworks.after_place(pos)
		end

		if minetest.settings:get_bool("creative_mode") then
			if not ninv:is_empty("main") then
				return nil
			else
				return itemstack
			end
		else
			return nil
		end
	end

	def_closed.after_dig_node = function(pos, oldnode, oldmetatbl, digger)
		-- NOTE: oldmeta is in table format
		if not digger then
			return
		end

		local inv = oldmetatbl.inventory.main
		-- These can be nil if the mesebox we're picking up is an older version.
		-- Default to reasonable values instead of crashing.
		if not oldmetatbl.fields or not oldmetatbl.fields.ratio or not oldmetatbl.fields.alias then
			oldmetatbl.fields = {
				ratio = "",
				alias = desc,
			}
		end
		local ratio = oldmetatbl.fields.ratio
		local alias = oldmetatbl.fields.alias

		-- Move items from the Node to the ItemStack.
		local items = {}
		local item_cnt = 0
		for i,v in ipairs(inv) do
			items[i] = v:to_string()
			if not v:is_empty() then item_cnt = item_cnt + 1 end
		end
		-- Copy our internal state variables.
		local fields = {}
		for k,v in pairs(oldmetatbl.fields) do
			fields[k] = v
		end
		local data = {
			items = items,
			fields = fields,
		}
		local istack = ItemStack("mesebox:"..color.."_mesebox")
		local imeta = istack:get_meta()
		imeta:set_string("description", alias.." "..ratio)
		-- Serialize and store the Node's inventory and internal variables
		-- in the ItemStack's metadata so it can be retrieved later when
		-- it is again placed in the world.
		imeta:set_string("data", minetest.serialize(data))

		local dinv = digger:get_inventory()
		if dinv:room_for_item("main", istack) then
			dinv:add_item("main", istack)
		else
			minetest.add_item(pos, istack)
		end

		if pipeworks_enabled then
			pipeworks.after_dig(pos)
		end
	end

	minetest.register_node(name, def_closed)
	minetest.register_node(name .. "_open", def_opened)
end



for color, desc in pairs(mesebox.variants) do
	local name = "mesebox:" .. color .. "_mesebox"
	mesebox.register_mesebox(name, color, desc)

	minetest.register_craft({
			type = "shapeless",
			output = "mesebox:"..color.."_mesebox",
			recipe = { "group:mesebox", "dye:"..color }
	})
end

minetest.register_craft({
		output = "mesebox:yellow_mesebox 1",
		recipe = {
			{ "group:wood", "group:wood",	"group:wood" },
			{ "group:wood", "default:mese", "group:wood" },
			{ "group:wood", "group:wood",	"group:wood" },
		}
})


-- Keep inventory of mesebox when changing color by crafting
minetest.register_on_craft(
	function(itemstack, player, old_craft_grid, craft_inv)
		local new = itemstack:get_name()
		if minetest.get_item_group(itemstack:get_name(), "mesebox") ~= 1 then
			return
		end
		-- Search for an existing Mesebox in the crafting grid and store in 'old'.
		local old
		for i = 1, #old_craft_grid do
			local item = old_craft_grid[i]:get_name()
			if minetest.get_item_group(item, "mesebox") == 1 then
				old = old_craft_grid[i]
				break
			end
		end
		if old then
			-- Crafting Mesebox with dye
			local ometa = old:get_meta()
			local imeta = itemstack:get_meta()

			local data = minetest.deserialize(ometa:get_string("data"))
			if data then
				-- Update name with name from new Mesebox and transfer table.
				local new_desc = itemstack:get_description()
				data.fields.alias = new_desc
				ometa:set_string("data", minetest.serialize(data))
				imeta:from_table(ometa:to_table())
				imeta:set_string("description", new_desc.." "..data.fields.ratio)
			else
				-- No 'data' means this Mesebox has never been placed.
				-- We set defaults in 'after_place_node' when the Mesebox is placed
				-- into the world for the first time so leave as is here.
				imeta:from_table(ometa:to_table())
			end
		else
			-- Couldn't find existing Mesebox in the crafting grid which
			-- means we're crafting a new one.
			-- We set defaults in 'after_place_node' when the Mesebox is placed
			-- into the world for the first time so leave as is here.
		end
		return itemstack
	end
)
