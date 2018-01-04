--for ammo loader:  luaForce.reset_technology_effects() --reapplies all technology effects, including unlocking recipes.

--0.16 Copy Paste from assembler to requester chest now scales with assembler speed and recipe crafting time.
--Added LuaEntityPrototype::allowed_effects read.
--Added LuaEntity::effects read.
--the effects being applied to this entity
--like 
--{
--	consumption=
--	{
--		bonus=0.6
--	},
--	speed =
--	{
--		bonus = -0.15
--	},
--	productivity =
--	{
--		bonus = 0.06
--	},
--	pollution = =
--	{
--		bonus = 0.075
--	}
--}
--bonus 0.5 means a value of 150%


script.on_event(defines.events.on_built_entity, function(event)
	local setting = settings.global["AutomaticLogisticChest-BuildOn"].value

	if setting == "Manual" or setting == "Both" then
		handleEvent(event)
	end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	local setting = settings.global["AutomaticLogisticChest-BuildOn"].value

	if setting == "Bot" or setting == "Both" then
		handleEvent(event)
	end
end)

function handleEvent(event)
	local bufferTimeRequester = settings.global["AutomaticLogisticChest-BuffertimeRequester"].value
	local bufferTimeProvider = settings.global["AutomaticLogisticChest-BuffertimeProvider"].value

	if (bufferTimeRequester == 0 and bufferTimeProvider == 0) then
		return
	end

	local connectionType = settings.global["AutomaticLogisticChest-ConnectionType"].value
	local overrideExisting = settings.global["AutomaticLogisticChest-OverrideExisting"].value
	
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
				
				if (created_entity.prototype.logistic_mode == "requester" and bufferTimeRequester > 0) then
					local inputs = {}
					
					for inserter = 1, #inserters do
						if inserters[inserter].pickup_target == nil and comparePositions(inserters[inserter].pickup_position, created_entity.position) then
							if inserters[inserter].drop_target ~= nil and (inserters[inserter].drop_target.type == "assembling-machine" or inserters[inserter].drop_target.type == "furnace") and inserters[inserter].drop_target.get_recipe() ~= nil then
								calcInputs(inserters[inserter].drop_target, inputs, bufferTimeRequester)
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
				elseif (created_entity.prototype.logistic_mode == "passive-provider" and bufferTimeProvider > 0) then
					for inserter = 1, #inserters do
						if inserters[inserter].drop_target == nil and comparePositions(inserters[inserter].drop_position, created_entity.position) then
							if inserters[inserter].pickup_target ~= nil and (inserters[inserter].pickup_target.type == "assembling-machine" or inserters[inserter].pickup_target.type == "furnace") and inserters[inserter].pickup_target.get_recipe() ~= nil then
								
								local outputs = {}
								calcOutputs(inserters[inserter].pickup_target, outputs, bufferTimeProvider)	
								
								for name in pairs(outputs) do
								
									local condition = 
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
									
									local controlBehavior = inserters[inserter].get_or_create_control_behavior()

									if overrideExisting or not (controlBehavior.get_circuit_network(defines.wire_type.green) ~=nil or controlBehavior.get_circuit_network(defines.wire_type.red) ~=nil or controlBehavior.connect_to_logistic_network == true) then
										if connectionType == "Logistic"  then
											controlBehavior.connect_to_logistic_network = true
											controlBehavior.logistic_condition = condition
										else
											if connectionType == "GreenCable" then
												created_entity.connect_neighbour(
												{
													wire = defines.wire_type.green,
													target_entity = inserters[inserter]
												})
											else
												created_entity.connect_neighbour(
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