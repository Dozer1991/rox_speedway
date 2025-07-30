-- client/fuel.lua

local FuelAPIs = {
  { name = "LegacyFuel",     fn = "SetFuel" },
  { name = "ox_fuel",        fn = "SetFuel" },
  { name = "mvrp_fuel",       fn = "SetFuel" },
  { name = "okokGasStation", fn = "SetFuel" },
}

local activeSetters = {}

CreateThread(function()
  for _, api in ipairs(FuelAPIs) do
    if GetResourceState(api.name) == "started"
    and exports[api.name]
    and exports[api.name][api.fn] then
      table.insert(activeSetters, exports[api.name][api.fn])
      print(("[ROX-Speedway] Fuel integration: %s detected"):format(api.name))
    end
  end
end)

function SetFullFuel(veh)
  SetVehicleFuelLevel(veh, 100.0)
  for _, setter in ipairs(activeSetters) do
    setter(veh, 100.0)
  end
end
