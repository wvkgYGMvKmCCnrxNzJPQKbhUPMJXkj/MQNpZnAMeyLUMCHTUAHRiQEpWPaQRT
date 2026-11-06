local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

--[[
Reference [Class].SkillInfo[skilltables]
NEW SKILL = { NumberOfAttacks, AttackName, Cooldown, Type, Range }
[1] = number of attacks for the designated skill table
[2] = name of attack being referenced
    ↳ a table of attacks will treat each value as its own attack (no number added)
    ↳ if you have a table of attacks add +1 to the number of attacks for each attack in the table
    ↳ GetRemote() will always return a table of attacks
[3] = cooldown for the attack
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", {1, 2, 3, 4}, type, range } = Slash cd 1, Slash cd 2, Slash cd 3 etc (cd = cooldown)
[4] = attack type (tables not supported)
[5] = attack range
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", cd, type, {1, 2, 3, 4} } = Slash r 1, Slash r 2, Slash r 3 etc (r = range)
SkipFirst = don't add a number to the end of the first attack
Rollback = remove 1 from the count each iteration (use if a class has an attack that goes from Attack → Attack1 → Attack2 etc )
IncrementD = number of attacks to go through before slowly increasing the attack distance for each new attack
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will start adding distance to each addition value created after it for that specific attack
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
AddCd = number of attacks to go through before adding more cooldown to each attack created after it (SHOULD ONLY BE USED IF INCREASE IS LINEAR)
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will add an additional cooldown
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
]]

local function GetRemote(Class, ...) -- name of class where "Class" is and "..." is all the other remote names entered past the name to return
    local RemoteTable = {}
    for Index, RemoteName in {...} do
        table.insert(RemoteTable, Remotes:WaitForChild(string.format(
        "Skillset_%s_%s",
        Class, RemoteName
        )))
    end
    return RemoteTable
end

local ClassData = {
    Swordmaster = {
        DisplayName = "Swordmaster",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Swordmaster", 0.34, "Melee", 20 }, -- m1
            { 5, "CrescentStrike", 5.1, "Ranged", 40 }, -- skill 1
            { 1, "Leap", 8.1, "Melee", 20 }, -- skill 2
            { 20, "SwordCyclone", 30.1, "Melee", 40 } -- ultimate
        }
    },
    Defender = {
        DisplayName = "Defender",
        Distance = "Melee",
        SkillInfo = {
            { 5, "Defender", 0.66, "Melee", 20 }, -- m1
            { 1, "Groundbreaker", 5.1, "Ranged", 20 }, -- skill 1
            { 8, "Spin", 8.1, "Melee", 20 }, -- skill 2
            { 1, "DefenderShield", 30.1, "Melee", 20 }, -- ultimate
            { 1, GetRemote("Defender", "Ultimate"), 1, "CFrameRemote", 20 } -- ultimate
        }
    },
    Mage = {
        DisplayName = "Arcane Mage",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "Mage", 0.33, "Ranged", 65 }, -- m1
            { 2, {"ArcaneBlast", "ArcaneBlastAOE"}, 5.1, "Ranged", 45 }, -- skill 1
            { 12, "ArcaneWave", 8.1, "Ranged", 40, IncrementD = {6, 5} }, -- skill 2
            { 1, "ArcaneAscension", 30.1, "Ranged", 75 } -- ultimate
        }
    },
    DualWielder = {
        DisplayName = "Dual Wielder",
        Distance = "Melee",
        SkillInfo = {
            { 10, "DualWield", 0.55, "Melee", 20, AddCd = {5, 0.20} }, -- m1
            { 1, "DashStrike", 6.1, "Melee", 20 }, -- skill 2
            { 10, "CrossSlash", 8.1, "Ranged", 50 }, -- skill 3
            { 8, "DualWieldUltimateHit", 30.1, "Ranged", 20 }, -- ultimate
            { 4, "DualWieldUltimateSlam", 30.1, "Ranged", 20, SkipFirst = true, Rollback = true }, -- ultimate
            { 16, "DualWieldUltimateSword", 30.1, "Ranged", 20 }, -- ultimate
            { 1, GetRemote("DualWielder", "AttackBuff"), 1, "Remote", 50 } -- skill 1
        }
    },
    IcefireMage = {
        DisplayName = "Elementalist",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "IcefireMage", 0.55, "Ranged", 100 }, -- m1
            { 1, "IcySpikes", 6.1, "Ranged", 40 }, -- skill 1 
            { 2, {"IcefireMageFireball", "IcefireMageFireballBlast"}, 7.1, "Ranged", 100 }, -- skill 2
            { 5, "LightningStrike", 10.1, "Ranged", 100 }, -- skill 3
            { 1, "IcefireMageUltimateFrost", 30.1, "Ranged", 100 }, -- ultimate
            { 10, "IcefireMageUltimateMeteor", 30.1, "Ranged", 100 } -- ultimate
        }
    },
    Guardian = {
        DisplayName = "Guardian",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Guardian", 0.6, "Melee", 20 }, -- m1
            { 3, "RockSpikes", 6.1, "Ranged", 30, IncrementD = {2, 2.5} }, -- skill 2
            { 8, "SlashFury", 8.1, "Ranged", 30 }, -- skill 3
            { 12, "SwordPrison", 30.1, "Ranged", 120, IncrementD = {7, 10} }, -- ultimate
            { 1, GetRemote("Guardian", "AggroDraw"), 1, "Remote", 180 }, -- skill 1
            { 1, GetRemote("Guardian", "Ultimate"), 1, "GuardianRemote", 180 } -- ultimate status
        }
    },
    MageOfLight = {
        DisplayName = "Mage of Light",
        Distance = "Ranged",
        SkillInfo = {
            { 4, {"MageOfLight", "MageOfLightBlast", "MageOfLightCharged", "MageOfLightBlastCharged"}, {0.26, 0.31, 0.34, 0.34}, "Ranged", 100 }, -- m1 and m1 boosted
            { 2, GetRemote("MageOfLight", "HealCircle", "Ultimate"), 1, "Remote", 100 }, -- skill 1 and ultimate
            { 1, GetRemote("MageOfLight", "Barrier"), 1, "PlayerRemote", 100 } -- skill 3
            -- skill 2 not needed
        }
    },
    Paladin = {
        DisplayName = "Paladin",
        Distance = "Melee",
        SkillInfo = {
            { 1, "BlockingPaladin", 0.37, "Ranged", 20 }, -- skill 1
            { 4, "Paladin", 0.52, "Melee", 20 }, -- m1
            { 4, "LightPaladin", 0.52, "Melee", 20 }, -- m1 boosted
            { 3, GetRemote("Paladin", "Block", "GuildedLight", "LightThrust"), 1, "Remote", 80 }, -- skill 2 and skill 3
            { 1, GetRemote("Paladin", "Ultimate"), 1, "PlayerPositionRemote", 80 } -- ultimate
        }
    },
    Berserker = {
        DisplayName = "Berserker",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Berserker", 0.51, "Melee", 20 }, -- m1
            { 1, "AggroSlam", 5.1, "Ranged", 40 }, -- skill 1
            { 8, "GigaSpin", 7.1, "Ranged", 40}, -- skill 2
            { 2, "Fissure", 10.1, "Ranged", 40 }, -- skill 3
            { 8, "FissureErrupt", 10.1, "Ranged", 60 }, -- ultimate
            { 2, GetRemote("Berserker", "AggroSlam", "Ultimate"), 1, "Remote", 60 } -- slam to take aggro and move ultimate fire and ultimate
        }
    },
    Archer = {
        DisplayName = "Spirit Archer",
        Distance = "Ranged",
        SkillInfo = {
            { 1, "Archer", 0.47, "Ranged", 80 }, -- m1
            { 9, "PiercingArrow", 5.1, "Ranged", 100 }, -- skill 1
            { 1, "SpiritBomb", 10.1, "Ranged", 210 }, -- skill 2
            { 8, "MortarStrike", 10.1, "Ranged", {60, 77, 94, 111, 128, 144, 162, 180} }, -- skill 3
            { 6, "HeavenlySword", 30.1, "Ranged", 145 }, -- ultimate
            { 1, "BackstepAttack", 3.1, "Ranged", 200 } -- dodge
        }
    },
    Dragoon = {
        DisplayName = "Dragoon",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Dragoon", 0.45, "Melee", 20 }, -- m1
            { 1, "DragoonDash", 6.1, "Ranged", 20 }, -- skill 1 
            { 10, "DragoonCross", 6.1, "Ranged", 20 }, -- skill 1
            { 5, "MultiStrike", 6.1, "Melee", 20 }, -- skill 2
            { 1, "DragoonFall", 8.1, "Melee", 20 }, -- skill 3
            { 1, "DragoonUltimate", 30.1, "Ranged", 50 }, -- ultimate
            { 18, "UltimateDragon", 30.1, "Ranged", 100 }, -- ultimate
            { 1, GetRemote("Dragoon", "Ultimate"), 1, "Remote", 100 } -- ultimate
            -- other dragoon remotes are handled in main script
        }
    },
    Demon = {
        DisplayName = "Demon",
        Distance = "Melee",
        SkillInfo = {
            { 9, "DemonDPS", {0.85, 1.2, 1.5, 1.85, 2.15, 2.55, 2.9, 3.3, 3.6}, "Melee", 20 }, -- m1
            { 9, "DemonDPS*Ult", {0.85, 1.2, 1.5, 1.85, 2.15, 2.55, 2.9, 3.3, 3.6}, "Melee", 20, FormatSkill = true }, -- m1 boosted
            { 3, "ScytheThrowDPS", 5.1, "Ranged", 150 }, -- skill 2
            { 9, "ScytheThrow", 5.1, "Ranged", 150 }, -- skill 2
            { 1, "DemonLifeStealDPS", 8.1, "Ranged", 60 }, -- skill 3
            { 3, "DemonSoulDPS", 30.1, "Ranged", 30 }, -- ultimate
            { 1, GetRemote("Demon", "Ultimate"), 1, "Remote", 150 } -- ultimate
            -- skill 1 handled by main script
        }
    },
    Warlord = {
        DisplayName = "Warlord",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Warlord", 0.42, "Melee", 20 }, -- m1
            { 1, "ChainsOfWar", 8.1, "Ranged", 75 }, -- skill 3
            { 1, "BlockingWarlord", 2.5, "Ranged", 20 }, -- skill 2
            { 3, "Piledriver", {5.1, 6.1, 7.1}, "Ranged", 13 }, -- skill 1
            { 5, "WarlordUltimate", 30.1, "Ranged", 55 }, -- ultimate
            { 1, GetRemote("Warlord", "Block"), 1, "Remote", 75 } -- skill 2
        }
    },
    Summoner = {
        DisplayName = "Summoner",
        Distance = "Ranged",
        SkillInfo = {
            { 4, "Summoner", {0.55, 0.75, 1.05, 1.3}, "Ranged", 80 }, -- m1
            { 5, "SoulHarvest", 1.1, "Ranged", 75 }, -- skill 3
            { 2, GetRemote("Summoner", "Summon", "Ultimate"), 1, "Remote", 80 } -- skill 1 and ultimate
        }
    },
    Assassin = {
        DisplayName = "Shadowblade",
        Distance = "Melee",
        SkillInfo = {
            { 8, "Assassin", 0.26, "Melee", 20 }, -- m1
            { 1, "ShadowLeap", 3.1, "Ranged", 50 }, -- skill 2
            { 2, "ShadowSlash", 6.1, "Ranged", 60 }, -- skill 3
            { 1, "RealmOfShadows", 30.1, "Ranged", 80 }, -- ultimate
            { 5, "ShadowMulti", 30.1, "Ranged", 60 }, -- ultimate
            { 2, GetRemote("Assassin", "EventStealthWalk", "Ultimate"), 1, "Remote", 60 } -- skill 1 and ultimate
        }
    },
    Stormcaller = {
        DisplayName = "Stormcaller",
        Distance = "Melee",
        SkillInfo = {
            { 3, "Stormcaller", 0.4, "Ranged", 100 }, -- m1
            { 8, "ChainLightning", 10.1, "Ranged", 120 }, -- skill 2
            { 2, {"StormSurgeInit", "StormSurge"}, 12.1, "Ranged", {20, 40} }, -- skill 3
            { 1, "UltimateDischarge", 1.5, "Ranged", 35 }, -- ultimate
            { 1, "StormcallerUltBlast", 30.1, "Melee", 44 }, -- ultimate
            { 8, "StormcallerThunderGod", {0.3, 0.5, 0.7, 1, 1.2, 1.6, 2, 2.3}, "Melee", 20 }, -- ultimate
            { 1, "ShockDashBall", 3.1, "Ranged", 40 }, -- dodge
            { 3, "ShockDash", 3.1, "Ranged", 40 }, -- dash
            { 1, GetRemote("Stormcaller", "Ultimate"), 1, "Remote", 120 } -- ultimate
        }
    },
    MageOfShadows = {
        DisplayName = "Mage of Shadows",
        Distance = "Ranged",
        SkillInfo = {
            { 4, {"MageOfShadows", "MageOfShadowsBlast", "MageOfShadowsCharged", "MageOfShadowsBlastCharged"} , {0.25, 0.5, 0.5, 0.5}, "Ranged", 100 }, -- m1 and m1 boosted
            { 1, "BighShadowOrb", 0.5, "Ranged", 100 }, -- skill 2
            { 1, "MageOfShadowsDamageCircle", 0.5, "Ranged", 125 }, -- skill 1
            { 1, GetRemote("MageOfShadows", "ShadowChains"), 6.1, "ShadowChain", 125 } -- skill 3
        }
    },
    Crusader = {
        DisplayName = "Crusader",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Crusader", 0.31, "Melee", 20 }, -- m1
            { 4, "CrusaderRally", 6.1, "Ranged", 30 }, -- skill 1
            { 4, "CrusaderDecree", 14.1, "Ranged", 130 }, -- skill 3
            { 5, "CrusaderGloryWave", 30.1, "Ranged", 100 }, -- ultimate
            { 1, "CrusaderGloryBlast", 30.1, "Ranged", 100 }, -- ultimate
            { 4, GetRemote("Crusader", "Rally", "Armament", "LightDash", "Ultimate"), {6.1, 11.1, 2.1, 1}, "Remote", 130 }, -- skill 1, skill 2, dodge, ultimate
            { 1, GetRemote("Crusader", "Decree"), 13.1, "MobPositionRemote", 130 } -- skill 3
        }
    },
    Hunter = {
        DisplayName = "Hunter",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "Hunter", 0.47, "Ranged", 80, SkipFirst = true }, -- m1
            { 5, "HunterExplosiveArrow", 4.1, "Ranged", 150, SkipFirst = true }, -- skill 1
            { 3, {"BearTrap", "BearTrapAOE", "FamiliarBurst"}, {1.1, 1.1, 5.1}, "Ranged", 150 }, -- skill 3
            { 10, "DivineArrow", 30.1, "Ranged", 150 }, -- ultimate
            { 1, "BackstepAttackHunter", 3.1, "Ranged", 150 }, -- dodge
            { 2, GetRemote("Hunter", "Summon", "Frenzy"), {15, 1}, "Remote", 150 }, -- skill 2
            { 1, GetRemote("Hunter", "ReplicateVisuals"), 1, "HunterTrapRemote", 150 }, -- skill 3
            { 1, GetRemote("Hunter", "DivineArrowHeal"), 2.5, "HunterRemote", 150 } -- ultimate
        }
    },
    Leviathan = {
        DisplayName = "Leviathan",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Leviathan", 0.45, "Melee", 20 }, -- m1
            { 1, "WaterCyclone", 0.25, "Ranged", 100 }, -- skill 1
            { 1, "Mealstrom", 0.45, "Ranged", 100 }, -- skill 2
            { 1, "Hydrosurge", 5.1, "Melee", 44 }, -- skill 3
            { 1, "MaelstromBubblePop", 10.1, "Ranged", 100 }, -- combo
            { 8, "LeviathanUltimate", 30.1, "Ranged", 40 }, -- ultimate
            { 1, GetRemote("Leviathan", "PoppingBubbleDamage"), 0.1, "TableRemote", 95 } -- bubble damage
        }
    },
    Starbreaker = {
        DisplayName = "Starbreaker",
        Distance = "Melee",
        SkillInfo = {
            { 1, "StarbreakerUltimateHitInit", 30.1, "Ranged", 20 }, -- m1 ult
            { 2, "StarforgeExplosion", 25.1, "Ranged", 20 }, -- skill 3
            { 10, "StarbreakerFlare", 10.1, "Ranged", 110 }, -- skill 2
            { 4, "Nova", 7.1, "Ranged", 60 }, -- skill 1
            { 1, "StarbreakerUltimateHit", 1.51, "Ranged", 115 }, -- ult activation
            { 1, "", 1.1, "StarbreakerWaves", 20 }, -- starforge wave boost
            { 8, "StarbreakerBoosted", 0.61, "Melee", 20 }, -- m1 boosted
            { 8, "Starbreaker", 0.61, "Melee", 20 }, -- m1
            { 1, GetRemote("Starbreaker", "Starforge"), 1, "MobPositionRemote", 115 }, -- skill 3
            { 1, GetRemote("Starbreaker", "Ultimate"), 1, "Remote", 115 } -- ultimate
        }
    },
    Necromancer = {
        DisplayName = "Necromancer",
        Distance = "Melee",
        SkillInfo = {
            { 9, "NecroDPS", {0.85, 1.2, 1.5, 1.9, 2.2, 2.5, 2.8, 3.2, 3.5}, "Melee", 20 }, -- m1
            { 5, "SpiritExplosion", {2.25, 2.25, 3, 3.25, 4}, "Melee", {12, 13, 15, 17, 20}, Rollback = true }, -- skill 2
            { 5, "TombstoneRise", 4.2, "Melee", 25 }, -- skill 1
            { 6, "SpiritCavern", 10.2, "Ranged", 150 }, -- skill 3
            { 1, "UltScytheDrop", 30.1, "Ranged", 150 }, -- ultimate
            { 1, GetRemote("Necromancer", "Ultimate"), 1, "Remote", 150 } -- ultimate
        }
    },
}
return ClassData
