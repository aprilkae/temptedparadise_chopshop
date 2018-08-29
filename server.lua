ESX 									= nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('tp_chopshop:sellVehicle')
AddEventHandler('tp_chopshop:sellVehicle', function(sellingPrice)
	print(sellingPrice)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	xPlayer.addAccountMoney('black_money', sellingPrice)
	TriggerClientEvent('pNotify:SendNotification', _source, {
		text = "Selling for: $" .. tostring(sellingPrice),
		type = "success",
		progressBar = false,
		queue = "choptime",
		timeout = 5000,
		layout = "centerleft"
		})
end)