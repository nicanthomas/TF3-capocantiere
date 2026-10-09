-- PROVA 14: linea merci a piu' fermate (raccolta da un'industria, consegna a quella che usa la merce, ritorno se c'e'),
-- 2 treni (binari d'attesa se i binari degli scali non bastano).
-- (09.10.2026) coppia fissa sulla "partita vuota di test": Cava di argilla -> Mattonificio di Castelgrande (la segheria di Centauro: nessun posto, 09.10)
-- (T.industryPair non trova altre coppie: quella di p4 e' gia' usata, le altre industrie sono sulla riva).
local from, to = 52765, 62781
local r = SIM_ACTIONS.build_cargo_rail_network({ pickup_ids = { from }, delivery_ids = { to }, num_trains = 2, num_cars = 5 })
r.pair = { CC.nameOf(from), CC.nameOf(to) }
return r
