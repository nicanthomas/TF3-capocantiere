-- PROVA 22: compra un aereo piccolo nell'hangar che raggiunge le fermate (16027, campo di Abriola) e lo assegna alla
-- linea della prova p20. Verifica che il problema fosse solo l'hangar senza uscita.
local id = api.res.modelRep.find("vehicle/plane/sukhoi_superjet_100/sukhoi_superjet_100.mdl")
local ok, v = CC.buyVehicles(16027, id, 1, 13619)
return { model = id, ok = ok, vehicles = v and v.vehicles, errors = v and v.errors, collaudo = CC.checkLine(13619) }
