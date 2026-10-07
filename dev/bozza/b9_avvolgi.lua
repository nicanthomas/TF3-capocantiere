-- ===================================================================== BOZZA (NON TESTATO) - b9 (va caricata per ULTIMA)
-- Avvolge tutte le azioni:
--   - controllo degli argomenti anche nella mod (azioni gia' esistenti: tabella SPECS; quelle nuove lo fanno da sole);
--   - registro di cio' che costruiscono -> result.created (il middleware lo salva per "annulla");
--   - se un'azione stradale fallisce senza creare la linea, toglie depositi e costruzioni appena fatti
--     (le fermate e i binari del tram restano: sono pezzi di strade cittadine);
--   - collaudo subito dopo la costruzione: per ogni linea creata, CC.checkLine (b8) -> result.collaudo;
--   - avviso se la partita risulta in pausa.
local NO_TX = { undo = true, check_line = true, check_network = true, read_map = true }
local CLEANUP_ON_FAIL = { build_tram_line = true, build_bus_line = true, connect_industry_to_city = true,
	build_intercity_bus = true, connect_station_to_town = true, build_air_or_water_line = true }
-- argomenti delle azioni gia' esistenti (gli stessi degli schemi di middleware/tools.py)
local SPECS = {
	build_bus_line = { town_id = "id", num_stops = "int?", num_vehicles = "int?", name = "str?" },
	build_tram_line = { town_id = "id", num_stops = "int?", num_vehicles = "int?", name = "str?" },
	build_station = { kind = "str", near_entity_id = "id", name = "str?" },
	build_line = { name = "str", station_ids = "ids", transport = "str" },
	build_rail_line = { town_ids = "ids", num_trains = "int?", num_cars = "int?", name = "str?" },
	buy_and_assign_vehicles = { line_id = "id", count = "int", depot_id = "id?", model = "str?" },
	connect_industry_to_city = { industry_id = "id", target_id = "id", transport = "str?", num_vehicles = "int?" },
}

for name, f in pairs(SIM_ACTIONS) do
	if not NO_TX[name] then
		SIM_ACTIONS[name] = function(a)
			if SPECS[name] then
				local okN, errN = pcall(CC.need, a, SPECS[name])
				if not okN then
					return { ok = false, error = tostring(errN), created = { vehicles = {}, lines = {}, constructions = {}, tracks = {}, roads = {} } }
				end
			end
			CC.txBegin()
			local ok, r = pcall(f, a)
			local tx = CC.txEnd()
			if not ok then r = { ok = false, error = tostring(r) } end
			if type(r) ~= "table" then r = { ok = true, value = r } end
			local created = CC.txClassify(tx)
			-- pulizia prudente: niente rimozioni se l'azione ha fatto anche binari o (aerei/navi) strade d'accesso
			local risky = #created.tracks > 0 or (name == "build_air_or_water_line" and #created.roads > 0)
			if risky and CLEANUP_ON_FAIL[name] and not r.ok and not r.line_id then
				CC.noteLeftovers(created.constructions, created.tracks)
				r.leftovers = { constructions = created.constructions, edges = created.tracks }
			elseif CLEANUP_ON_FAIL[name] and not r.ok and not r.line_id and #created.constructions > 0 then
				local n = 0
				for i = #created.constructions, 1, -1 do
					if CC.removeConstruction(created.constructions[i]) then n = n + 1 end
				end
				r.cleanup = n .. " costruzioni rimosse (fermate e strade cittadine restano)"
				created = CC.txClassify(tx)
			end
			r.created = created
			-- collaudo subito: le linee create (o indicate nel risultato)
			local toCheck, seen = {}, {}
			for _, L in ipairs(r.line_ids or {}) do if not seen[L] then seen[L] = true; toCheck[#toCheck + 1] = L end end
			if r.line_id and not seen[r.line_id] then toCheck[#toCheck + 1] = r.line_id end
			if #toCheck > 0 and CC.checkLine then
				r.collaudo = {}
				for _, L in ipairs(toCheck) do
					local okC, C = pcall(CC.checkLine, L)
					r.collaudo[#r.collaudo + 1] = okC and { line_id = L, ok = C.ok, problems = C.problems, suggestions = C.suggestions }
						or { line_id = L, ok = false, problems = { "collaudo non eseguito: " .. tostring(C) } }
				end
			end
			if CC.gameSpeed() == 0 then r.warning = "la partita e' in pausa" end
			return r
		end
	end
end
-- ===================================================================== fine b9
