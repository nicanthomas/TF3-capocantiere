-- SONDA 22: moduli (slot=nome) delle costruzioni ferroviarie modulari del giocatore (scalo merci fatto a mano).
local CT = api.type.ComponentType
local player = api.engine.util.getPlayer()
local out = {}
for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
	local po = CC.comp(con, CT.PLAYER_OWNED)
	local c = CC.comp(con, CT.CONSTRUCTION)
	if po and po.player == player and tostring(c.fileName):find("modular_station", 1, true) then
		local r = { id = con, params = {}, modules = {} }
		pcall(function()
			for k, v in pairs(c.params) do
				if k == "modules" then
					for slot, m in pairs(v) do r.modules[#r.modules + 1] = tostring(slot) .. "=" .. tostring(m.name) .. "|" .. tostring(m.variant) end
				else r.params[tostring(k)] = tostring(v) end
			end
		end)
		table.sort(r.modules)
		pcall(function() r.ends = #CC.railStationEnds(con) end)
		out[#out + 1] = r
	end
end
return out
