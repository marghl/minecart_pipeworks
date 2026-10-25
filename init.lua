-- Pipeworks integration for joe7575's Minecart Hopper.
--
-- This is deliberately kept outside the minecart mod so that upstream updates
-- do not overwrite the integration.

local HOPPER = "minecart:hopper"
local TRANSFER_COUNT = 4

local hopper_def = minetest.registered_nodes[HOPPER]
if not hopper_def then
	minetest.log("warning", "[minecart_pipeworks] minecart:hopper is not registered; integration disabled")
	return
end

local function hopper_inventory(pos)
	return minetest.get_meta(pos):get_inventory()
end

local function may_access(pos, owner)
	if not owner or owner == "" then
		return true
	end
	return not minetest.is_protected(pos, owner)
end

local function return_above(pos, stack)
	if stack and not stack:is_empty() then
		minecart.untake_items({x = pos.x, y = pos.y + 1, z = pos.z}, nil, stack)
	end
end

local function take_from_above_into_buffer(pos, inv)
	local stack = minecart.take_items(
		{x = pos.x, y = pos.y + 1, z = pos.z}, nil, TRANSFER_COUNT)
	if not stack then
		return false
	end

	local leftover = inv:add_item("main", stack)
	return_above(pos, leftover)
	return leftover:get_count() < stack:get_count()
end

local function scan_dropped_items(pos, inv)
	local scan_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
	for _, object in ipairs(minetest.get_objects_inside_radius(scan_pos, 1)) do
		local entity = object:get_luaentity()
		if not object:is_player() and entity and entity.name == "__builtin:item"
				and entity.itemstring ~= "" then
			local stack = ItemStack(entity.itemstring)
			if inv:room_for_item("main", stack) then
				inv:add_item("main", stack)
				object:remove()
			end
		end
	end
end

local function move_buffer_to_output(pos, inv, output_dir)
	local stack = minecart.inv_take_items(inv, "main", TRANSFER_COUNT)
	if not stack then
		return false
	end

	local leftover = minecart.put_items(pos, output_dir, stack)
	if leftover and not leftover:is_empty() then
		inv:add_item("main", leftover)
	end
	return not leftover or leftover:get_count() < stack:get_count()
end

-- Preserve the normal rear-to-output transfer. If no source exists there,
-- unload a cart above into the Hopper's own buffer. Pipeworks can then extract
-- the cargo through an adjacent injector/filter tube.
local function pipeworks_hopper_timer(pos)
	local inv = hopper_inventory(pos)
	local output_dir = (minetest.get_node(pos).param2 + 1) % 4
	local stack = minecart.take_items(pos, output_dir, TRANSFER_COUNT)

	if stack then
		local leftover = minecart.put_items(pos, output_dir, stack)
		if leftover and not leftover:is_empty() then
			minecart.untake_items(pos, output_dir, leftover)
		end
		return true
	end

	if not take_from_above_into_buffer(pos, inv) then
		scan_dropped_items(pos, inv)
	end
	move_buffer_to_output(pos, inv, output_dir)
	return true
end

local old_after_place = hopper_def.after_place_node
local old_after_dig = hopper_def.after_dig_node
local groups = table.copy(hopper_def.groups or {})
groups.tubedevice = 1
groups.tubedevice_receiver = 1

minetest.override_item(HOPPER, {
	groups = groups,
	on_timer = pipeworks_hopper_timer,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		if old_after_place then
			old_after_place(pos, placer, itemstack, pointed_thing)
		end
		pipeworks.scan_for_tube_objects(pos)
	end,
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		if old_after_dig then
			old_after_dig(pos, oldnode, oldmetadata, digger)
		end
		pipeworks.scan_for_tube_objects(pos)
	end,
	tube = {
		connect_sides = {
			left = 1, right = 1, front = 1,
			back = 1, top = 1, bottom = 1,
		},
		input_inventory = "main",
		can_insert = function(pos, node, stack, direction, owner)
			return may_access(pos, owner)
				and hopper_inventory(pos):room_for_item("main", stack)
		end,
		insert_object = function(pos, node, stack, direction, owner)
			if not may_access(pos, owner) then
				return stack
		end
			minetest.get_node_timer(pos):start(2)
			return hopper_inventory(pos):add_item("main", stack)
		end,
		remove_items = function(pos, node, stack, direction, count, listname, index)
			local inv = hopper_inventory(pos)
			local current = inv:get_stack(listname, index)
			local taken = current:take_item(count)
			inv:set_stack(listname, index, current)
			return taken
		end,
	},
})

minetest.log("action", "[minecart_pipeworks] Pipeworks integration enabled for minecart:hopper")

