-- SONDA 34 (sola lettura): costruzioni e binari lasciati da una prova. Stazioni del giocatore il cui nome contiene
-- CC.RESTI_NOMI (es. " stazione"); per ognuna i binari collegati (seguendo i nodi fino alla prossima costruzione o a un
-- estremo libero, anche attraverso gli scambi). Risultato: { constructions = {...}, tracks = {...} } per l'annulla.
local CT = api.type.ComponentType
local want = CC.RESTI_NOMI or { " stazione" }
local cons, tracks, seenE, info = {}, {}, {}, {}
for g in pairs(CC.playerGroups()) do
	local n = CC.nameOf(g) or ""
	local hit = false
	for _, w in ipairs(want) do if n:find(w, 1, true) then hit = true end end
	if hit then
		local sg = CC.comp(g, CT.STATION_GROUP)
		local st = sg and CC.each(sg.stations)[1]
		local okC, con = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, st)
		if okC and con and con >= 0 then
			cons[#cons + 1] = con
			info[#info + 1] = n .. " -> " .. con
			local stack = {}
			for _, e in ipairs(CC.railStationEnds(con)) do stack[#stack + 1] = e.node end
			local seenN = {}
			while #stack > 0 do
				local node = table.remove(stack)
				if not seenN[node] then
					seenN[node] = true
					for _, e in ipairs(CC.each(api.engine.system.streetSystem.getNodeSegments(node))) do
						if not seenE[e] and not CC.inConstruction(e) then
							local be = CC.comp(e, CT.BASE_EDGE)
							if be and tostring(be.roadTemplate):find("/track/", 1, true) then
								seenE[e] = true
								tracks[#tracks + 1] = e
								stack[#stack + 1] = be.node0; stack[#stack + 1] = be.node1
							end
						end
					end
				end
			end
		end
	end
end
-- depositi del giocatore attaccati a quei binari
local deps = {}
for _, e in ipairs(tracks) do
	local be = CC.comp(e, CT.BASE_EDGE)
	for _, nd in ipairs({ be.node0, be.node1 }) do
		for _, s in ipairs(CC.each(api.engine.system.streetSystem.getNodeSegments(nd))) do
			if CC.inConstruction(s) then
				local okC, c = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForEdge, s)
				if okC and c and c >= 0 then deps[c] = true end
			end
		end
	end
end
for c in pairs(deps) do
	local found = false
	for _, x in ipairs(cons) do if x == c then found = true end end
	if not found then cons[#cons + 1] = c end
end
return { info = info, constructions = cons, tracks = tracks, nTracks = #tracks }
