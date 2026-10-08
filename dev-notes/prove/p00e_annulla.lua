-- Annulla (una fase per chiamata) quanto costruito dalla prova precedente: CC.UNDO_CREATED = result.created.
return SIM_ACTIONS.undo({ created = CC.UNDO_CREATED })
