script.on_event(defines.events.on_built_entity, function(event)
	handleEvent(event)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	handleEvent(event)
end)

function handleEvent(event)
	local created_entity = event.created_entity

	if created_entity.type == "logistic-container" then
		if created_entity.prototype ~= nil and created_entity.prototype.logistic_mode ~= nil and (created_entity.prototype.logistic_mode == "requester" or created_entity.prototype.logistic_mode == "passive-provider") then
			local inserters = created_entity.surface.find_entities_filtered(
			{
				area =
				{
					{
						x = created_entity.position.x - 2,
						y = created_entity.position.y - 2
					},
					{
						x = created_entity.position.x + 2,
						y = created_entity.position.y + 2
					}
				},
				type = "inserter"
			})
			
			if #inserters > 0 then
				
				if (created_entity.prototype.logistic_mode == "requester") then
					local inputs = {}
					
					for inserter = 1, #inserters do
						if inserters[inserter].pickup_target == nil and comparePositions(inserters[inserter].pickup_position, created_entity.position) then 
							if inserters[inserter].drop_target ~= nil and (inserters[inserter].drop_target.type == "assembling-machine" or inserters[inserter].drop_target.type == "furnace") and (inserters[inserter].drop_target.recipe ~=nill or inserters[inserter].drop_target.previous_recipe ~=nill) then
								calc_inputs(inserters[inserter].drop_target, inputs)
							end
						end
					end
					local slot = 1
					for name in pairs(inputs) do
						created_entity.set_request_slot(
						{
							name = name,
							count = math.ceil(inputs[name])
						},
						slot)
						slot = slot + 1
					end
				elseif (created_entity.prototype.logistic_mode == "passive-provider") then
					for inserter = 1, #inserters do
						if inserters[inserter].drop_target == nil and comparePositions(inserters[inserter].drop_position, created_entity.position) then
							if inserters[inserter].pickup_target ~= nil and (inserters[inserter].pickup_target.type == "assembling-machine" or inserters[inserter].pickup_target.type == "furnace") and (inserters[inserter].pickup_target.recipe ~=nill or inserters[inserter].pickup_target.previous_recipe ~= nil) then
								
								local outputs = {}
								
								calc_outputs(inserters[inserter].pickup_target, outputs)				
								for name in pairs(outputs) do
									created_entity.connect_neighbour(
									{
										wire = defines.wire_type.red,
										target_entity = inserters[inserter]
									})
									
									local controlBehavior = inserters[inserter].get_or_create_control_behavior()
									controlBehavior.circuit_condition = 
									{
										condition = 
										{
											comparator = "<",
											first_signal =
											{
												type = "item",
												name = name
											},
											constant = math.ceil(outputs[name])
										}
									}
								end
							end
						end
					end
				end
			end
		end
	end
end


function comparePositions(position1, position2)
	
	return position1.x > position2.x - 0.5 and position1.x < position2.x + 0.5 and position1.y > position2.y - 0.5 and position1.y < position2.y + 0.5

end

-- calculate the required input for an entity
function calc_inputs(entity, inputs)

	local beacon_speed_effect = check_beacons(entity)

	local modeffects =
	{
		speed = 0,
		prod = 0
	}
	
	modeffects = calc_mods(entity, modeffects, 1)

	-- calculate the craftingspeed of the entity
	local crafting_speed = entity.prototype.crafting_speed * ( 1 + modeffects.speed + beacon_speed_effect)
	
	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.recipe.energy / crafting_speed
	
	local recipe = entity.recipe
	if recipe == nil then
		recipe = entity.previous_recipe
	end
	
	-- if craftingtime > buffertime buffer enough items for one craft, else buffer how much the entity consumes in the buffertime
	for _, ingred in ipairs(recipe.ingredients) do
		local amount = 0
		if ingred.type == "item" then
			if ingred.amount ~= nil then
				amount = ingred.amount
			end
		end
		
		if amount > 0 then
			if(craftingTime < buffertime) then
				amount = (amount / craftingTime) * buffertime
			end
			
			if inputs[ingred.name] == nil then
				inputs[ingred.name] = 0
			end
					
			inputs[ingred.name] = inputs[ingred.name] + amount
		end
		
	end
end

-- calculate the output of an entity
function calc_outputs(entity, outputs)

	local beacon_speed_effect = check_beacons(entity)

	local modeffects =
	{
		speed = 0,
		prod = 0
	}
	
	modeffects = calc_mods(entity, modeffects, 1)

	-- calculate the craftingspeed of the entity
	local crafting_speed = entity.prototype.crafting_speed * ( 1 + modeffects.speed + beacon_speed_effect)
	
	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.recipe.energy / crafting_speed
	
	local recipe = entity.recipe
	if recipe == nil then
		recipe = entity.previous_recipe
	end
	
	-- if craftingtime > buffertime buffer the items of one craft, else buffer how much the entity crafts in the buffertime
	for _, product in ipairs(recipe.products) do
		local amount = 0
		if product.type == "item" then
			if product.amount ~= nil then
				amount = product.amount
			elseif product.amount_min ~= nil and product.amount_max ~= nil and product.probability ~= nil then
				amount = ((product.amount_min + product.amount_max)/ 2) * product.probability
			end
		end
		
		if amount > 0 then
			if(craftingTime < buffertime) then
				amount = (amount / craftingTime) * buffertime
			end
			
			if outputs[product.name] == nil then
				outputs[product.name] = 0
			end
					
			outputs[product.name] = outputs[product.name] + amount
		end
	end
end

-- calculate speed effects of beacons.
function check_beacons(entity)
	
	local modeffects =
	{
		speed = 0,
		prod = 0
	}
	
	local x = entity.position.x
	local y = entity.position.y
	local machine_box = entity.prototype.selection_box
	local beacon_dist = game.entity_prototypes["beacon"].supply_area_distance

	for _,beacon in pairs(entity.surface.find_entities_filtered
	{ area = 
		{
			{
				x + machine_box.left_top.x - beacon_dist,
				y + machine_box.left_top.y - beacon_dist
			}, 
			{
				x + machine_box.right_bottom.x + beacon_dist,
				y + machine_box.right_bottom.y + beacon_dist
			}
		},
		type="beacon"
	}) do	
		calc_mods(beacon, modeffects, 0.5)
	end
	
	return modeffects.speed

end

-- calculate the effects of all the modules in the entity and adds it to modeffects.
function calc_mods(entity, modeffects, effectivity)
	local modinv = entity.get_module_inventory()
	local modcontents = modinv.get_contents()

	for modname,modquant in pairs(modcontents) do
		calc_mod(modname, modeffects, modquant, effectivity)
	end 

	return modeffects
end

-- calculate the effects of a single module and adds it to modeffects.
function calc_mod(modname, modeffects, modquant, effectivity )
	local protoeffects = game.item_prototypes[modname].module_effects
	
	for effectname,effectvals in pairs(protoeffects) do
		for _,bonamount in pairs(effectvals) do
			if effectname == "speed" then
				modeffects.speed = modeffects.speed + ( bonamount * modquant * effectivity)
			elseif effectname == "productivity" then
				modeffects.prod = modeffects.prod + (bonamount * modquant  * effectivity)
			end
		end
	end
end