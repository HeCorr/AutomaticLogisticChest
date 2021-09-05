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

function handleEvent(entity)
	if entity ~= nil and entity.type ~= nil then
		if entity.type == "inserter" then
			
			local pickup_target = getPickupTarget(entity)
			local drop_target = getDropTarget(entity)

			if pickup_target ~= nil and pickup_target.type ~= nil and pickup_target.type == "logistic-container" then
				handleEvent(pickup_target)
			end
			if drop_target ~= nil and drop_target.type ~= nil and drop_target.type == "logistic-container" then
				handleEvent(drop_target)
			end

		elseif entity.type == "logistic-container" then
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
		
			if entity.prototype ~= nil and entity.prototype.logistic_mode ~= nil and (entity.prototype.logistic_mode == "requester" or entity.prototype.logistic_mode == "passive-provider") then
				local inserters = entity.surface.find_entities_filtered(
				{
					area =
					{
						{
							x = entity.position.x - 3,
							y = entity.position.y - 3
						},
						{
							x = entity.position.x + 3,
							y = entity.position.y + 3
						}
					},
					type = "inserter"
				})
			
				if (#inserters > 0) then
					
					if (entity.prototype.logistic_mode == "requester" and bufferTimeRequester > 0) then
						local inputs = {}
						
						for inserter = 1, #inserters do
							local pickupTarget = getPickupTarget(inserters[inserter])
							if (pickupTarget ~= nil and pickupTarget == entity) then
								local dropTarget = getDropTarget(inserters[inserter])
								if (dropTarget ~= nil and dropTarget.type ~= nil and (dropTarget.type == "assembling-machine" or dropTarget.type == "furnace") and dropTarget.get_recipe() ~= nil) then
									calcInputs(dropTarget, inputs, bufferTimeRequester)
								end
							end
						end

						if (next(inputs) ~= nil) then					
							for requestSlot = 1, entity.request_slot_count do
								entity.clear_request_slot(requestSlot)
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

								entity.set_request_slot(
								{
									name = itemName,
									count = math.ceil(itemCount)
								}, slot)
								slot = slot + 1
							end
						end
					elseif (entity.prototype.logistic_mode == "passive-provider" and bufferTimeProvider > 0) then
						for inserter = 1, #inserters do
							local dropTarget = getDropTarget(inserters[inserter])
							if (dropTarget ~= nil and dropTarget == entity) then
								local pickupTarget = getPickupTarget(inserters[inserter])
								if (pickupTarget ~= nil and pickupTarget.type ~= nil and (pickupTarget.type == "assembling-machine" or pickupTarget.type == "furnace") and pickupTarget.get_recipe() ~= nil) then
									
									local outputs = {}
									calcOutputs(pickupTarget, outputs, bufferTimeProvider)	
									
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

										if (overrideExisting or not (controlBehavior.get_circuit_network(defines.wire_type.green) ~=nil or controlBehavior.get_circuit_network(defines.wire_type.red) ~=nil or controlBehavior.connect_to_logistic_network == true)) then
											if (connectionType == "Logistic")  then
												controlBehavior.connect_to_logistic_network = true
												controlBehavior.logistic_condition = condition
											else
												if (connectionType == "GreenCable") then
													entity.connect_neighbour(
													{
														wire = defines.wire_type.green,
														target_entity = inserters[inserter]
													})
												else
													entity.connect_neighbour(
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
end

function getPickupTarget(inserter)
	if (inserter.pickup_target ~= nil) then
		return inserter.pickup_target
	else
		local pickup_targets = inserter.surface.find_entities_filtered(
			{
				position = inserter.pickup_position
			})
		if (#pickup_targets > 0) then
			return pickup_targets[1]
		else
			return nil
		end
	end
end

function getDropTarget(inserter)
	if (inserter.drop_target ~= nil) then
		return inserter.drop_target
	else
		local drop_targets = inserter.surface.find_entities_filtered(
			{
				position = inserter.drop_position
			})
		if (#drop_targets > 0) then
			return drop_targets[1]
		else
			return nil
		end
	end
end

-- calculate the required input for an entity
function calcInputs(entity, inputs, bufferTime)

	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.get_recipe().energy / entity.crafting_speed
	
	-- if craftingtime > bufferTime buffer enough items for one craft, else buffer how much the entity consumes in the bufferTime
	for _, ingred in ipairs(entity.get_recipe().ingredients) do
		local amount = 0
		if (ingred.type == "item") then
			if (ingred.amount ~= nil) then
				amount = ingred.amount
			end
		end
		
		if (amount > 0) then
			if(craftingTime < bufferTime) then
				amount = (amount / craftingTime) * bufferTime
			end
			
			if (inputs[ingred.name] == nil) then
				inputs[ingred.name] = 0
			end
					
			inputs[ingred.name] = inputs[ingred.name] + amount
		end
	end
end

-- calculate the output of an entity
function calcOutputs(entity, outputs, bufferTime)

	-- calculate the real craftingtime of this entity for this recipe
	local craftingTime = entity.get_recipe().energy / entity.crafting_speed
	
	-- if craftingtime > bufferTime buffer the items of one craft, else buffer how much the entity crafts in the bufferTime
	for _, product in ipairs(entity.get_recipe().products) do
		local amount = 0
		if (product.type == "item")then
			if (product.amount ~= nil) then
				amount = product.amount
			elseif (product.amount_min ~= nil and product.amount_max ~= nil and product.probability ~= nil) then
				amount = ((product.amount_min + product.amount_max)/ 2) * product.probability
			end
		end
		
		if (amount > 0) then
			amount = amount * (1 + entity.productivity_bonus)

			if(craftingTime < bufferTime) then
				amount = (amount / craftingTime) * bufferTime
			end
			
			if (outputs[product.name] == nil) then
				outputs[product.name] = 0
			end
			
			outputs[product.name] = outputs[product.name] + amount
		end
	end
end