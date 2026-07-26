extends RefCounted
## Wardrobe data: 5 outfits unlocked by lifetime kills (persisted in user://save.cfg).

const OUTFITS = [
	{"id":"funeral",  "n":"FUNERAL BLACK",  "kills":0,   "accent":Color(0.227, 0.290, 0.478), "tie":false, "veil":false},
	{"id":"rider",    "n":"WHITE RIDER",    "kills":25,  "accent":Color(0.930, 0.930, 0.960), "tie":false, "veil":false},
	{"id":"tactical", "n":"NIGHT TACTICAL", "kills":75,  "accent":Color(0.070, 0.070, 0.090), "tie":false, "veil":false},
	{"id":"wick",     "n":"THE SUIT",       "kills":150, "accent":Color(0.040, 0.040, 0.050), "tie":true,  "veil":false},
	{"id":"bride",    "n":"BLOOD WEDDING",  "kills":300, "accent":Color(0.950, 0.910, 0.850), "tie":false, "veil":true},
]

static func unlocked_count(lifetime_kills: int) -> int:
	var n := 0
	for o in OUTFITS:
		if int(o["kills"]) <= lifetime_kills:
			n += 1
	return n

static func unlocked_list(lifetime_kills: int) -> Array:
	var out: Array = []
	for i in OUTFITS.size():
		if int(OUTFITS[i]["kills"]) <= lifetime_kills:
			out.append(i)
	return out
