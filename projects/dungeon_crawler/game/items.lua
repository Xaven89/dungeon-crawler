-- items: the item table, loot tables and the loot boxes ("Crates of Consequence").
Game = Game or {}
local G = Game
local I = {}
G.items = I

I.rarity = {
    common   = { name = "Common",    color = "#c8ccd4", weight = 60 },
    uncommon = { name = "Uncommon",  color = "#5fd35f", weight = 28 },
    rare     = { name = "Rare",      color = "#4aa8ff", weight = 9 },
    epic     = { name = "Epic",      color = "#c06cff", weight = 2.5 },
    legend   = { name = "Legendary", color = "#ffb030", weight = 0.5 },
}

I.defs = {}
local function def(id, d)
    d.id = id
    d.rarity = d.rarity or "common"
    d.color = I.rarity[d.rarity].color
    d.max_stack = d.max_stack or ((d.kind == "consumable" or d.kind == "junk") and 20 or 1)
    d.value = d.value or 5
    I.defs[id] = d
end

-- ---- weapons: dmg = { min, max }, reach in metres, cd = ticks between swings, fx = what it does besides hurting
def("mop",        { kind = "weapon", name = "Regulation Mop",             desc = "Standard issue. Smells of other people's problems.", dmg = { 6, 9 },  reach = 2.8, cd = 30, value = 1 })
def("torch_used", { kind = "weapon", name = "Torch (Slightly Used)",      desc = "Technically a tool. Practically a lawsuit.",         dmg = { 5, 8 },  reach = 2.4, cd = 26, value = 1, burn = 0.25 })
def("lute",       { kind = "weapon", name = "Lute of Last Resort",        desc = "Plays one chord. The chord is 'ow'.",                dmg = { 5, 9 },  reach = 2.6, cd = 28, value = 1 })
def("stapler",    { kind = "weapon", name = "Heavy-Duty Stapler",         desc = "Binds documents and enemies alike.",                 dmg = { 4, 7 },  reach = 2.2, cd = 18, value = 1 })
def("sword_mild", { kind = "weapon", name = "Sword of Mild Disappointment", desc = "It cuts. It also sighs.",                         dmg = { 9, 13 }, reach = 2.7, cd = 28, rarity = "uncommon", value = 40 })
def("mace_pa",    { kind = "weapon", name = "Mace of Passive Aggression", desc = "Hits slowly. Hits hard. Says 'fine.'",              dmg = { 14, 20 }, reach = 2.8, cd = 44, rarity = "uncommon", value = 55 })
def("dagger_cd",  { kind = "weapon", name = "Cease-and-Desist Dagger",    desc = "Very fast. Very formal.",                            dmg = { 5, 8 },  reach = 2.1, cd = 12, rarity = "uncommon", value = 45 })
def("axe_ot",     { kind = "weapon", name = "Unpaid Overtime Axe",        desc = "Swings itself after hours.",                         dmg = { 15, 22 }, reach = 2.9, cd = 38, rarity = "rare", value = 120, str = 2 })
def("rolling",    { kind = "weapon", name = "Rolling Pin of Reckoning",   desc = "Grandma's finest. The reckoning is flaky.",         dmg = { 11, 16 }, reach = 2.5, cd = 26, rarity = "rare", value = 110, con = 1 })
def("excalibur",  { kind = "weapon", name = "Legally Distinct Excalibur", desc = "Pulled from a stone. Not THE stone. A similar stone.", dmg = { 20, 28 }, reach = 3.0, cd = 30, rarity = "epic", value = 300, cha = 3 })
def("spoon",      { kind = "weapon", name = "The Sharpest Spoon",         desc = "There is no spoon. There is only this.",            dmg = { 26, 34 }, reach = 2.6, cd = 22, rarity = "legend", value = 800, dex = 4, burn = 0.3 })

-- ---- armour (def: damage taken is reduced by this much per hit) and trinkets
def("cardboard",  { kind = "armor", name = "Cardboard Breastplate",       desc = "Water-resistant. Not goblin-resistant.",             def = 2, value = 8 })
def("hivis",      { kind = "armor", name = "Hi-Vis Vest of Safety Theatre", desc = "You are extremely visible. To everything.",        def = 3, value = 25, rarity = "uncommon" })
def("bathrobe",   { kind = "armor", name = "Bathrobe of Unearned Confidence", desc = "Grants +2 swagger. Does not grant armor, the number is a lie.", def = 4, cha = 2, rarity = "uncommon", value = 45 })
def("potlid",     { kind = "armor", name = "Pot-Lid Pauldrons",           desc = "Clatters heroically.",                               def = 5, rarity = "rare", value = 90, con = 1 })
def("tux",        { kind = "armor", name = "Tuxedo of Tasteful Doom",     desc = "Black tie. Black hole. Black humour.",               def = 8, rarity = "epic", value = 280, cha = 3, con = 2 })
def("duck",       { kind = "trinket", name = "Lucky Rubber Duck",         desc = "+2 DEX. Squeaks when danger is near. Always squeaks.", dex = 2, value = 30, rarity = "uncommon" })
def("coupon",     { kind = "trinket", name = "Expired Coupon (40% Off)",  desc = "+15% gold from kills. Expired in the year 2019.",    gold_bonus = 0.15, value = 35, rarity = "uncommon" })
def("trophy",     { kind = "trinket", name = "Participation Trophy",      desc = "+3 CON. You showed up. That's the achievement.",     con = 3, value = 60, rarity = "rare" })
def("monocle",    { kind = "trinket", name = "Monocle of Mild Suspicion", desc = "+3 INT. Sees through lies and some walls.",         int = 3, value = 70, rarity = "rare" })

-- ---- consumables (use from the hotbar: 1..8)
def("smoothie",   { kind = "consumable", name = "Mystery Smoothie",       desc = "Restores 40 health. Do not ask about the colour.",   heal = 40, value = 12 })
def("bandage",    { kind = "consumable", name = "Bandage (Previously Owned)", desc = "Restores 25 health. Slightly warm.",              heal = 25, value = 6 })
def("sushi",      { kind = "consumable", name = "Gas Station Sushi",      desc = "Restores 90 health. Roll the dice on tomorrow.",     heal = 90, value = 35, rarity = "uncommon" })
def("energy",     { kind = "consumable", name = "Energy Drink (Extreme)", desc = "Restores 35 mana. Your heart files a complaint.",    mana = 35, value = 14 })
def("firecracker", { kind = "consumable", name = "Firecracker of Opportunity", desc = "Throw at the thing in front of you. Loud.",      throw = "boom", value = 18 })
def("cheese",     { kind = "consumable", name = "Wheel of Fate (Cheese)", desc = "Restores 60 health and 20 mana. Gouda choice.",      heal = 60, mana = 20, value = 40, rarity = "rare" })

-- ---- quest items and junk (it sells)
def("keycard",    { kind = "quest", name = "Floor Manager's Keycard",     desc = "Opens the way down. Laminated.",                     value = 0, rarity = "epic" })
def("valve_wheel", { kind = "quest", name = "Valve Wheel (Sticky)",       desc = "Fits the sewer valve. Do not smell it.",             value = 0, rarity = "uncommon" })
def("hairball",   { kind = "junk", name = "Ball of Unidentified Hair",    desc = "Sells for something. Somewhere. Probably.",          value = 3 })
def("receipt",    { kind = "junk", name = "Soggy Receipt",                desc = "For services rendered. The services were violence.", value = 4 })
def("gnome",      { kind = "junk", name = "Garden Gnome (Suspicious)",    desc = "He is watching the show too.",                       value = 22, rarity = "uncommon" })
def("goldtooth",  { kind = "junk", name = "Gold Tooth",                   desc = "Not yours. Not anymore.",                            value = 30, rarity = "uncommon" })
def("gem",        { kind = "junk", name = "Gem of Moderate Sparkle",      desc = "A rock that learned to network.",                    value = 55, rarity = "rare" })

-- the loot tables: lists of ids per box tier
I.tables = {
    bronze   = { "smoothie", "bandage", "energy", "cardboard", "hairball", "receipt", "sword_mild", "dagger_cd", "duck", "firecracker", "hivis" },
    silver   = { "sushi", "smoothie", "energy", "sword_mild", "mace_pa", "dagger_cd", "hivis", "bathrobe", "duck", "coupon", "rolling", "gnome", "goldtooth", "firecracker" },
    gold     = { "sushi", "cheese", "axe_ot", "rolling", "potlid", "trophy", "monocle", "bathrobe", "mace_pa", "gem", "coupon" },
    platinum = { "excalibur", "tux", "spoon", "trophy", "monocle", "cheese", "axe_ot", "potlid" },
    goblin   = { "hairball", "receipt", "goldtooth", "bandage", "smoothie", "gnome", "firecracker" },
    drop     = { "bandage", "smoothie", "energy", "hairball", "receipt", "goldtooth" },
}

I.tiers = {
    bronze   = { name = "Bronze Crate of Consequence",   color = "#c98a4b", rolls = { 1, 2 }, gold = { 8, 25 } },
    silver   = { name = "Silver Crate of Consequence",   color = "#c8d0e0", rolls = { 2, 3 }, gold = { 25, 60 } },
    gold     = { name = "Gold Crate of Consequence",     color = "#ffd24a", rolls = { 3, 4 }, gold = { 60, 140 } },
    platinum = { name = "Platinum Crate of Consequence", color = "#9ff0ff", rolls = { 3, 4 }, gold = { 200, 400 } },
}

function I.roll(tier_name, salt)
    local t = I.tables[tier_name] or I.tables.bronze
    local id = t[1 + math.floor(G.hash(salt or 1, #t, G.state and G.state.kills or 0) * #t) % #t]
    return id
end

-- the inventory (the engine's sample: stacks, hotbar, bag, saved with the project)
function I.init()
    include("engine/ui_kit.lua")
    include("engine/inventory.lua")
    I.inv = inventory.new{ name = "player", slots = 24, hotbar = 8, columns = 6, items = I.defs }
    inventory.load(I.inv)
    return I.inv
end

function I.add(id, n)
    local left = inventory.add(I.inv, id, n or 1)
    inventory.save(I.inv)
    return left == 0
end
function I.count(id) return inventory.count(I.inv, id) end
function I.remove(id, n) local t = inventory.remove(I.inv, id, n or 1); inventory.save(I.inv); return t end
function I.has(id) return inventory.count(I.inv, id) > 0 end

-- an item's name coloured for the announcer / log text is not needed; items speak for themselves
function I.describe(id)
    local d = I.defs[id]
    if not d then return id end
    local lines = { d.name, I.rarity[d.rarity].name .. " " .. d.kind, d.desc or "" }
    if d.dmg then lines[#lines + 1] = string.format("damage %d-%d   reach %.1f m   swing %.1f s", d.dmg[1], d.dmg[2], d.reach, d.cd / 60) end
    if d.def then lines[#lines + 1] = "armour " .. d.def end
    if d.heal then lines[#lines + 1] = "restores " .. d.heal .. " health" end
    if d.mana then lines[#lines + 1] = "restores " .. d.mana .. " mana" end
    for _, s in ipairs({ "str", "dex", "int", "con", "cha" }) do if d[s] then lines[#lines + 1] = string.format("+%d %s", d[s], s:upper()) end end
    lines[#lines + 1] = "worth " .. d.value .. " gold"
    return table.concat(lines, "\n")
end
