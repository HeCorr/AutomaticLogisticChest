script.on_event("AutomaticLogisticChest-HotKeyHoover", function(event)
	local player = game.players[event.player_index]
	handleEvent(player.selected)	
end)

script.on_event("AutomaticLogisticChest-HotKeyAll", function(event)
	for id, surf in pairs(game.surfaces) do
		local chests = surf.find_entities_filtered({type = "logistic-container"})
		for chest = 1, #chests do
			handleEvent(chests[chest])
		end
    end
end)

script.on_event(defines.events.on_built_entity, function(event)
	local setting = settings.global["AutomaticLogisticChest-BuildOn"].value

	if setting == "Manual" or setting == "Both" then
		handleEvent(event.created_entity)
	end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	local setting = settings.global["AutomaticLogisticChest-BuildOn"].value

	if setting == "Bot" or setting == "Both" then
		handleEvent(event.created_entity)
	end
end)

function handleEvent(chest)
	if chest ~= nil and chest.type ~= nil and chest.type == "logistic-container" then
		local bufferTimeRequester = settings.global["AutomaticLogisticChest-BuffertimeRequester"].value
		local bufferTimeProvider = settings.global["AutomaticLogisticChest-BuffertimeProvider"].value

		if (bufferTimeRequester == 0 and bufferTimeProvider == 0) then
			return
		end

		local connectionType = settings.global["AutomaticLogisticChest-ConnectionType"].value
		local overrideExisting = settings.global["AutomaticLogisticChest-OverrideExisting"].value
		
		local minRequester = settings.global["AutomaticLogisticChest-MinRequester"].value
		local maxRequester = settings.global["AutomaticLogisticChest-MaxRequester"].value
		local minProvider = settings.global["AutomaticLogisticChest-MinProvider"].value
		local maxProvider = settings.global["AutomaticLogisticChest-MaxProvider"].value
	
		if chest.prototype ~= nil and chest.prototype.logistic_mode ~= nil and (chest.prototype.logistic_mode == "requester" or chest.prototype.logistic_mode == "passive-provider") then
			local inserters = chest.surface.find_entities_filtered(
			{
				area =
				{
					{
						x = chest.position.x - 2,
						y = chest.position.y - 2
					},
					{
						x = chest.position.x + 2,
						y = chest.position.y + 2
					}
				},
				type = "inserter"
			})
		
			if #inserters > 0 then
				
				if (chest.prototype.logistic_mode == "requester" and bufferTimeRequester > 0) then
					local inputs = {}
					
					for inserter = 1, #inserters do
						if inserters[inserter].pickup_target == chest or (inserters[inserter].pickup_target == nil and comparePositions(inserters[inserter].pickup_position, chest.position)) then
							if inserters[inserter].drop_target ~= nil and (inserters[inserter].drop_target.type == "assembling-machine" or inserters[inserter].drop_target.type == "furnace") and inserters[inserter].drop_target.get_recipe() ~= nil then
								calcInputs(inserters[inserter].drop_target, inputs, bufferTimeRequester)
							end
						end
					end

					if #inputs > 0 then					
						for requestSlot = 1, chest.request_slot_count do
							chest.clear_request_slot(requestSlot)
						end

						local slot = 1
						for itemName in pairs(inputs) do
							local itemCount = math.ceil(inputs[itemName])

							local proto = game.item_prototypes[itemName]
							if (minRequester > 0 and itemCount < proto.stack_size * minRequester) then
								itemCount = proto.stack_size * minRequester
							end

							if (maxRequester > 0 and itemCount > proto.stack_size * maxRequester) then
								itemCount = proto.stack_size * maxRequester
							end

							chest.set_request_slot(
							{
								name = itemName,
								count = math.ceil(itemCount)
							}, slot)
							slot = slot + 1
						end
					end
				elseif (chest.prototype.logistic_mode == "passive-provider" and bufferTimeProvider > 0) then
					for inserter = 1, #inserters do
						if inserters[inserter].drop_target == chest or (inserters[inserter].drop_target == nil and comparePositions(inserters[inserter].drop_position, chest.position)) then
							if inserters[inserter].pickup_target ~= nil and (inserters[inserter].pickup_target.type == "assembling-machine" or inserters[inserter].pickup_target.type == "furnace") and inserters[inserter].pickup_target.get_recipe() ~= nil then
								
								local outputs = {}
								calcOutputs(inserters[inserter].pickup_target, outputs, bufferTimeProvider)	
								
								for itemName in pairs(outputs) do
									local itemCount = math.ceil(outputs[itemName])

									local proto = game.item_prototypes[itemName]
									if (minProvider > 0 and itemCount < proto.stack_size * minProvider) then
										itemCount = proto.stack_size * minProvider
									end

									if (maxProvider > 0 and itemCount > proto.stack_size * maxProvider) then
										itemCount = proto.stack_size * maxProvider
									end

									local condition = 
									{
										condition = 
										{
											comparator = "<",
											first_signal =
											{
												type = "item",
												name = itemName
											},
											constant = math.ceil(itemCount)
										}
									}
									
									local controlBehavior = inserters[inserter].get_or_create_control_behavior()

									if overrideExisting or not (controlBehavior.get_circuit_network(defines.wire_type.green) ~=nil or controlBehavior.get_circuit_network(defines.wire_type.red) ~=nil or controlBehavior.connect_to_logistic_network == true) then
										if connectionType == "Logistic"  then
											controlBehavior.connect_to_logistic_network = true
											controlBehavior.logistic_condition = condition
										else
											if connectionType == "GreenCable" then
												chest.connect_neighbour(
												{
													wire = defines.wire_type.green,
													target_entity = inserters[inserter]
												})
											else
												chest.connect_neighbour(
												{
													wire = defines.wire_type.red,
													target_entity = inserters[inserter]
												})
											end

											controlBehavior.circuit_condition = condition
										end
									end
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
function calcInputs(entity, inputs, bufferTime)

	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.get_recipe().energy / getCraftingSpeed(entity)
	
	-- if craftingtime > bufferTime buffer enough items for one craft, else buffer how much the entity consumes in the bufferTime
	for _, ingred in ipairs(entity.get_recipe().ingredients) do
		local amount = 0
		if ingred.type == "item" then
			if ingred.amount ~= nil then
				amount = ingred.amount
			end
		end
		
		if amount > 0 then
			if(craftingTime < bufferTime) then
				amount = (amount / craftingTime) * bufferTime
			end
			
			if inputs[ingred.name] == nil then
				inputs[ingred.name] = 0
			end
					
			inputs[ingred.name] = inputs[ingred.name] + amount
		end
	end
end

-- calculate the output of an entity
function calcOutputs(entity, outputs, bufferTime)

	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.get_recipe().energy / getCraftingSpeed(entity)
	
	-- if craftingtime > bufferTime buffer the items of one craft, else buffer how much the entity crafts in the bufferTime
	for _, product in ipairs(entity.get_recipe().products) do
		local amount = 0
		if product.type == "item" then
			if product.amount ~= nil then
				amount = product.amount
			elseif product.amount_min ~= nil and product.amount_max ~= nil and product.probability ~= nil then
				amount = ((product.amount_min + product.amount_max)/ 2) * product.probability
			end
		end
		
		if amount > 0 then
			if(craftingTime < bufferTime) then
				amount = (amount / craftingTime) * bufferTime
			end
			
			if outputs[product.name] == nil then
				outputs[product.name] = 0
			end
					
			outputs[product.name] = outputs[product.name] + amount
		end
	end
end

function getCraftingSpeed(entity)
	local craftingSpeed = entity.prototype.crafting_speed

	if entity.effects ~= nil then
		if entity.effects.speed ~= nil then
			craftingSpeed = entity.prototype.crafting_speed * ( 1 + entity.effects.speed.bonus )
		end
	end

	return craftingSpeed
end