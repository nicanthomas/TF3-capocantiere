-- PROVA 37 (punto 1b): linea merci su strada usando le stazioni INTEGRATE delle industrie (s35: ogni industria a terra
-- ha una stazione per camion propria, non del giocatore). Cava di argilla -> Mattonificio di Castelgrande.
local r = SIM_ACTIONS.connect_industry_to_city({ industry_id = 52765, target_id = 62781, num_vehicles = 2 })
return r
