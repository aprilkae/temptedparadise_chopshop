ESX 													= nil
local vehiclePrice 						= nil
local modifiedPrice	 					= vehiclePrice
local hasList									= false
local possibleVehicles				= {}
local carList									= {}
local phoneNumber							= nil
local timeRemaining						= 0
local hasChip									= false
local hasAlreadyEnteredMarker = false
local sellingPrice						= 0
local sellingLocation					= nil

local dropPoints = {
	{name="LSC by the Airport", x=-1166.96, y=-2013.09, z=12.00},
	{name="LCS in Harmony", x=1182.72, y=2638.11, z=36.98},
	{name="Hayes Auto on Macdonald", x=288.8, y=-1730.0, z=28.5},
	{name="Route 68 Mechanic in Harmony", x=258.89, y=2588.06, z=44.0},
	{name="mechanic shop on Little Bighorn", x=479.96, y=-1318.15, z=28.0}
}

-- base thread
Citizen.CreateThread(function()
  while ESX == nil do
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    Citizen.Wait(0)
  end

  Citizen.Wait(10000)

  ESX.TriggerServerCallback('esx_vehicleshop:getVehicles', function(vehicles)
  	possibleVehicles = vehicles
  	end)
end)


AddEventHandler('esx:playerLoaded', function(source)

	local xPlayer = ESX.GetPlayerFromId(source)

	while phoneNumber == nil do
		MySQL.Async.fetchAll(
			'SELECT phone_number FROM users WHERE identifier = @identifier',
			{
				['@identifier'] = xPlayer.identifier
			}, 
			function(result)

				phoneNumber = result[1].phone_number

				if phoneNumber == nil then
					Wait(10000)
				end
			end
		)
	end
end)


if hasList == false or time == 0 then
	Citizen.CreateThread(function()
		while true do
			Wait(0)
			if nearList() then
				DisplayHelpText("Press ~INPUT_PICKUP~ to access the list ~b~")

				if IsControlJustPressed(1, 38) then
					hasChip = checkInventory() -- check to see if the player has a black chip
					--Citizen.Trace("has chip value " .. tostring(hasChip))
					if hasChip and timeRemaining == 0 then
						hasList = true
						TriggerEvent('tp_chopshop:getList')
					elseif hasChip and timeRemaining ~= 0  then
						TriggerEvent('pNotify:SetQueueMax', "choptime", 1)
						TriggerEvent('pNotify:SendNotification', {
							text = "You still have seconds " .. timeRemaining .. " remaining on your last list",
							type = "error",
							progressBar = false,
							queue = "choptime",
							timeout = 5000,
							layout = "Centerleft"
							})
					elseif not hasChip then
						TriggerEvent('pNotify:SendNotification', {
							text = "You must have a chip to access the computer",
							type = "error",
							progressBar = false,
							queue = "choptime",
							timeout = 5000,
							layout = "centerleft"
						})
					end
				end
			end
		end	
	end)
end

RegisterNetEvent('tp_chopshop:checkVehicle')
AddEventHandler('tp_chopshop:checkVehicle', function()
if hasList and time ~= 0 and IsPedInAnyVehicle(GetPlayerPed(-1), false) then
	Citizen.CreateThread(function()
		local playerPed = GetPlayerPed(-1)
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		local match = false

		local initialPrice = 0
		local sellingCar = nil
		-- check to see if the current vehicle matches any from their list
		for k, v in pairs(carList) do
			Citizen.Trace(tostring(v.hashKey) .. " vs " .. GetEntityModel(vehicle))
			if v.hashKey == GetEntityModel(vehicle) then
				match = true
				sellingCar = v.name
				initialPrice = v.price
				break
			end
		end

		if match then
			local carHealth = GetVehicleEngineHealth(GetVehiclePedIsIn(playerPed))
			local carHealthModifier = carHealth/1000
			sellingPrice = rounded(carHealthModifier * initialPrice, 0)
			Citizen.Wait(2000)
			TriggerServerEvent('tp_chopshop:sellVehicle', sellingPrice)
			for i=0, 7, 1 do
				SetVehicleDoorOpen(vehicle, i, false, true)
				Citizen.Wait(500)
			end
			Citizen.Wait(5000)
			DeleteVehicle(vehicle)
			sellingPrice = 0
			sellingCar = nil
			
			-- remove vehicle from the table
			local u = 1
			while u <= #carList do
				if carList[u].name == sellingCar then
					table.remove(carList, u)
					break
				else
					u = u + 1
				end
			end
		else
			TriggerEvent('pNotify:SendNotification', {
				text = "This isn't the correct vehicle!",
				type = "error",
				progressBar = false,
				queue = "choptime",
				timeout = 5000,
				layout = "centerleft"
				})
		end
	end)
end
end)


RegisterNetEvent('tp_chopshop:getList')
AddEventHandler('tp_chopshop:getList', function ()
	-- get the random location
	local randomLocation = math.random(1, 5)

	for q = 1, #dropPoints, 1 do
		if q == randomLocation then
			sellingLocation = dropPoints[q].name
			break
		end
	end

	-- count the number of available cars
	local length = 1

	for k, v in pairs(possibleVehicles) do
		length = length + 1
	end

	-- find a random vehicle
	for i = 1, 5, 1 do
		local number = math.random(1, length)

		table.insert(carList, {
			id 				= possibleVehicles[number].id,
			name			= possibleVehicles[number].name,
			model 		= possibleVehicles[number].model,
			price 		= rounded(possibleVehicles[number].price * .35),
			category 	= possibleVehicles[number].category,
			hashKey		= GetHashKey(possibleVehicles[number].model)
			})
	end

	local sendList = {}
	for o, car in pairs(carList) do
		table.insert(sendList, tostring(car.name))
	end

	local message = "You have 45 minutes to find me these 5 vehicles: " .. table.concat(sendList, ", ") .. ". Drop it off at the " .. sellingLocation .."."

	TriggerEvent('esx_phone:onMessage', phoneNumber, message, false, true, 'player', false)

	setTimer()
end)

-- marker for drop point
Citizen.CreateThread(function()
	while true do

		Citizen.Wait(0)
		local coords = GetEntityCoords(GetPlayerPed(-1))

		for _, drops in pairs(dropPoints) do
			if(GetDistanceBetweenCoords(coords, drops.x, drops.y, drops.z, true) < 100.0) then
				DrawMarker(25, drops.x, drops.y, drops.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 5.0, 5.0, 3.0, 64, 63, 28, 100, false, true, 2, false, false, false, false)
			end
		end
		-- if(GetDistanceBetweenCoords(coords, 479.96, -1318.15, 28.6, true) < 100.0) then
		-- 	DrawMarker(25, 479.96, -1318.15, 28.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 5.0, 5.0, 3.0, 64, 63, 28, 100, false, true, 2, false, false, false, false)
		-- end
	end
end)

-- marker actions
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		local coords = GetEntityCoords(GetPlayerPed(-1))
		local inMarker = false
		local match = false

		-- if(GetDistanceBetweenCoords(coords, 479.96, -1318.15, 28.6, true) < 2.0) then
		-- 	inMarker = true
		-- end

		for k, v in pairs(dropPoints) do
			if v.name == sellingLocation and (GetDistanceBetweenCoords(coords, v.x, v.y, v.z, true) < 2.0) then
				inMarker = true
				match = true
			end
		end

		-- 	if match == false then
		-- 		TriggerEvent('pNotify:SendNotification', {
		-- 			text = "This isn't the right location!",
		-- 			type = "error",
		-- 			progressBar = false,
		-- 			queue = "choptime",
		-- 			timeout = 5000,
		-- 			layout = "centerleft"
		-- 		})
		-- 	end
		-- end

		if inMarker and not hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = true
			TriggerEvent('tp_chopshop:checkVehicle')
		end

		if not inMarker and hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = false
		end
	end
end)

function nearList()
	local player = GetPlayerPed(-1)
	local playerloc = GetEntityCoords(player, 0)

	local chopX = 471.94
	local chopY = -1310.49
	local chopZ = 28.22

	local distance = GetDistanceBetweenCoords(chopX, chopY, chopZ, playerloc['x'], playerloc['y'], playerloc['z'], true)

	if distance <= 2 then
		return true
	end
end

function nearDrop()
	local player = GetPlayerPed(-1)
	local playerloc = GetEntityCoords(player, 0)

	local dropX = 479.96
	local dropY = -1318.66
	local dropZ = 29.20

	local distance = GetDistanceBetweenCoords(dropX, dropY, dropZ, playerloc['x'], playerloc['y'], playerloc['z'], true)

	if distance <= 2 then
		return true
	end
end

function setTimer()
	Citizen.CreateThread(function()
		timeRemaining = 2700
		while time ~= 0 do
			Wait(1000)
			timeRemaining = timeRemaining - 1
			if timeRemaining == 0 then
				hasList = false
				clearList(carList)
				clearList(sendList)
				break
			end
		end
	end)
end

function checkInventory()
	local inventory = ESX.GetPlayerData().inventory
	local amount = 0

	for i=1, #inventory, 1 do
		if inventory[i].name == 'black_chip' then
			amount = inventory[i].count
			break
		end
	end

	if(amount > 0) then
		hasChip = true
		return true
	else
		hasChip = false
		return false
	end
end


function clearList(list)
	for k, v in pairs(list) do
		list[k] = nil
	end
end

function DisplayHelpText(str)
	SetTextComponentFormat("STRING")
	AddTextComponentString(str)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

function rounded(number, decimalPlaces)
	local multiplier = 10^(decimalPlaces or 0)
	return math.floor(number * multiplier + 0.5) / multiplier
end 