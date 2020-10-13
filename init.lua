-- Mesebox

-- XXX: Public because default.chest was so. Maybe make private if it makes
-- no sense for a public API here.
mesebox = {}
mesebox.mesebox = {}

local pipeworks_enabled = minetest.get_modpath("pipeworks") ~= nil

function mesebox.mesebox.get_mesebox_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec = "size[8,8.75]" ..
		"label[0,0;"..minetest.formspec_escape(minetest.colorize("#fff", "Mesebox")).."]"..
		"list[nodemeta:" .. spos .. ";main;0,0.5;8,3;]" ..
		"label[0,4.0;"..minetest.formspec_escape(minetest.colorize("#fff", "Inventory")).."]"..
		"list[current_player;main;0,4.5;8,1;]"..
		default.get_hotbar_bg(0,4.5,8,1)..
		"list[current_player;main;0,5.75;8,3;8]"..
		default.get_hotbar_bg(0,5.75,8,3)..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]"
	return formspec
end

function mesebox.mesebox.mesebox_lid_close(pn)
	local mesebox_open_info = mesebox.mesebox.open_meseboxs[pn]
	local pos = mesebox_open_info.pos
	local sound = mesebox_open_info.sound
	local swap = mesebox_open_info.swap

	mesebox.mesebox.open_meseboxs[pn] = nil
	for k, v in pairs(mesebox.mesebox.open_meseboxs) do
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

function mesebox.mesebox.can_open(pos)
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

mesebox.mesebox.open_meseboxs = {}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "default:mesebox" then
		return
	end
	if not player or not fields.quit then
		return
	end
	local pn = player:get_player_name()

	if not mesebox.mesebox.open_meseboxs[pn] then
		return
	end

	mesebox.mesebox.mesebox_lid_close(pn)
	return true
end)

minetest.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	if mesebox.mesebox.open_meseboxs[pn] then
		mesebox.mesebox.mesebox_lid_close(pn)
	end
end)

function mesebox.mesebox.update_infotext(pos, desc)
	-- update infotext
	local nmeta = minetest.get_meta(pos)
	local ninv = nmeta:get_inventory()
	local size = 24
	local count = 0
	for i = 1, size do
		if not ninv:get_stack("main", i):is_empty() then count = count + 1 end
	end
	nmeta:set_string("infotext", desc.." ["..count.."/"..size.."]")
end

function mesebox.mesebox.register_mesebox(name, color, desc)
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

	def.on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", desc.." [0/24]")
		local inv = meta:get_inventory()
		inv:set_size("main", 8*3)
	end

	def.on_rightclick = function(pos, node, clicker)
		-- XXX: The Scanner is currently blocking from opening so don't do this for now.
		-- if not mesebox.mesebox.can_open(pos) then
		-- 	return
		-- end
		minetest.sound_play(def.sound_open, {gain = 0.5, pos = pos,
						     max_hear_distance = 10}, true)
		minetest.swap_node(pos, { name = name .. "_open",
					  param2 = node.param2 })
		minetest.after(0.2, minetest.show_formspec,
			       clicker:get_player_name(),
			       "default:mesebox", mesebox.mesebox.get_mesebox_formspec(pos))
		mesebox.mesebox.open_meseboxs[clicker:get_player_name()] = {
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
		mesebox.mesebox.update_infotext(pos, desc)
	end

	def.on_metadata_inventory_take = function(pos, listname, index, stack, player)
		mesebox.mesebox.update_infotext(pos, desc)
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
		local imeta = itemstack:get_metadata()
		local iinv_main = minetest.deserialize(imeta)
		ninv:set_list("main", iinv_main)
		ninv:set_size("main", 8*3)

		-- update infotext
		local size = 24
		local count = 0
		for i = 1, size do
			if not ninv:get_stack("main", i):is_empty() then count = count + 1 end
		end
		nmeta:set_string("infotext", desc.." ["..count.."/"..size.."]")

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

	def_closed.after_dig_node = function(pos, oldnode, oldmeta, digger)
		if not digger then
			return
		end

		local inv = oldmeta.inventory.main

		local items = {}
		local size = 0
		local count = 0
		for i,v in ipairs(inv) do
			items[i] = v:to_string()
			if items[i] ~= "" then
				count = count + 1
			end
			size = size + 1
		end
		local data = minetest.serialize(items)
		local boxitem = ItemStack("mesebox:"..color.."_mesebox")
		boxitem:set_metadata(data)

		local meta = boxitem:get_meta()
		meta:set_string("description", desc.." ["..count.."/"..size.."]")

		local dinv = digger:get_inventory()
		if dinv:room_for_item("main", boxitem) then
			dinv:add_item("main", boxitem)
		else
			minetest.add_item(pos, boxitem)
		end

		if pipeworks_enabled then
			pipeworks.after_dig(pos)
		end
	end

	minetest.register_node(name, def_closed)
	minetest.register_node(name .. "_open", def_opened)
end



local meseboxes = {
	white = "White Mesebox",
	black = "Black Mesebox",
	red = "Red Mesebox",
	blue = "Blue Mesebox",
	green = "Green Mesebox",
	yellow = "Yellow Mesebox",
	orange = "Orange Mesebox",
	violet = "Violet Mesebox",
}

for color, desc in pairs(meseboxes) do
	local name = "mesebox:" .. color .. "_mesebox"
	mesebox.mesebox.register_mesebox(name, color, desc)

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
		local old
		for i = 1, #old_craft_grid do
			local item = old_craft_grid[i]:get_name()
			if minetest.get_item_group(item, "mesebox") == 1 then
				old = old_craft_grid[i]
				break
			end
		end
		if old then
			local ometa = old:get_meta():to_table()
			local nmeta = itemstack:get_meta()
			nmeta:from_table(ometa)
			return itemstack
		end
	end
)
