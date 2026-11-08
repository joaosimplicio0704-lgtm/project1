-- Net
-- Contrato de rede entre servidor e cliente.

local Net = {}

Net.FolderName = "Remotes"
Net.State = "State"
Net.Action = "Action"
Net.Event = "Event"

Net.ActionKind = {
	Tap = "tap",
	Hatch = "hatch",
	Equip = "equip",
	Unequip = "unequip",
	SelectEgg = "selectEgg",
	BuyUpgrade = "buyUpgrade",
	BuyGemUpgrade = "buyGemUpgrade",
	Rebirth = "rebirth",
	Golden = "golden",
	Fuse = "fuse",
	SellPet = "sellPet",
	ClaimQuest = "claimQuest",
	SetZone = "setZone",
	Travel = "travel",
	CollectMine = "collectMine",
	RushMine = "rushMine",
}

Net.EventKind = {
	Toast = "toast",
	Hatch = "hatch",
	Rebirth = "rebirth",
	Zone = "zone",
	Travel = "travel",
	Mine = "mine",
}

-- Zonas interativas do mapa (click detector -> abre UI no cliente)
Net.Zones = {
	Eggs = "eggs",
	Shop = "shop",
	GemShop = "gemshop",
	Golden = "golden",
	Fusion = "fusion",
	Trade = "trade",
	Rebirth = "rebirth",
	Portal = "portal",
	Mine = "mine",
}

return Net
