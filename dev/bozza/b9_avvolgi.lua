-- ===================================================================== BOZZA (NON TESTATO) - b9 (va caricata per ULTIMA)
-- Avvolge tutte le azioni:
--   - registro di cio' che costruiscono -> result.created (il middleware lo salva per "annulla");
--   - se un'azione stradale fallisce senza creare la linea, toglie depositi e costruzioni appena fatti
--     (le fermate e i binari del tram restano: sono pezzi di strade cittadine);
--   - avviso se la partita risulta in pausa.
local NO_TX = { undo = true }
local CLEANUP_ON_FAIL = { build_tram_line = true, build_bus_line = true, connect_industry_to_city = true,
	build_intercity_bus = true, connect_station_to_town = true }

for name, f in pairs(SIM_ACTIONS) do
	if not NO_TX[name] then
		SIM_ACTIONS[name] = function(a)
			CC.txBegin()
			local ok, r = pcall(f, a)
			local tx = CC.txEnd()
			if not ok then r = { ok = false, error = tostring(r) } end
			if type(r) ~= "table" then r = { ok = true, value = r } end
			local created = CC.txClassify(tx)
			if CLEANUP_ON_FAIL[name] and not r.ok and not r.line_id and #created.constructions > 0 then
				local n = 0
				for i = #created.constructions, 1, -1 do
					if CC.removeConstruction(created.constructions[i]) then n = n + 1 end
				end
				r.cleanup = n .. " costruzioni rimosse (fermate e strade restano)"
				created = CC.txClassify(tx)
			end
			r.created = created
			if CC.gameSpeed() == 0 then r.warning = "la partita e' in pausa" end
			return r
		end
	end
end
-- ===================================================================== fine b9
