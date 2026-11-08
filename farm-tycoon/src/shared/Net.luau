-- Net
-- Nomes de remotes compartilhados entre servidor e cliente.
-- Um RemoteEvent "Action" (cliente -> servidor) e um "Event" (servidor -> cliente)
-- com discriminador `kind`. Menos boilerplate, mesma validacao no servidor.

local Net = {}

Net.FolderName = "Remotes"
Net.State = "State"
Net.Action = "Action"
Net.Event = "Event"

-- kinds de Action (cliente manda)
Net.ActionKind = {
	SelectCrop = "selectCrop",
	BuyPlot = "buyPlot",
	BuyUpgrade = "buyUpgrade",
	BuyAuto = "buyAuto",
	BuyCrystal = "buyCrystal",
	Rebirth = "rebirth",
	Redeem = "redeem",
	Harvest = "harvest",
}

-- kinds de Event (servidor manda)
Net.EventKind = {
	Toast = "toast",
	Sale = "sale",
	LevelUp = "levelUp",
	Rebirth = "rebirth",
}

return Net
