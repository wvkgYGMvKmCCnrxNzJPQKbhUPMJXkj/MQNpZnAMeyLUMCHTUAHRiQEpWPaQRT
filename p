--[[
Reference [Class].SkillInfo[skilltables]
NEW SKILL = { NumberOfAttacks, AttackName, Cooldown, Type, Range }
[1] = number of attacks for the designated skill table
[2] = name of attack being referenced
    ↳ a table of attacks will treat each value as its own attack (no number added)
    ↳ if you have a table of attacks add +1 to the number of attacks for each attack in the table
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

PetData = {
    Bite = {
        SkillInfo = {
            { 1, "Bite", 15.1, "Ranged", 95 }
        }
    },
    Scratch = {
        SkillInfo = { 
            { 1, "Scratch", 15.1, "Ranged", 95 }
        }
    },
    Fireball = {
        SkillInfo = {
            { 2, {"PetFireball", "PetFireballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    FireballGreen = {
        SkillInfo = {
            { 2, {"PetFireballGreen", "PetFireballBlastGreen"}, 15.1, "Ranged", 95 }
        }
    },
    Iceball = {
        SkillInfo = {
            { 2, {"PetIceball", "PetIceballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    PoisonSplash = {
        SkillInfo = {
            { 1, "PetPoisonSplash", 15.1, "Ranged", 95 }
        }
    },
    HealPulse = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    IcySpikes = {
        SkillInfo = {
            { 1, "PetIcySpikes", 15.1, "Ranged", 95 }
        }
    },
    BlackFlame = {
        SkillInfo = {
            { 6, "PetBlackFlame", 20.1, "Ranged", 95 }
        }
    },
    LightningStrike = {
        SkillInfo = {
            { 5, "PetLightningStrike", 25.1, "Ranged", 95 }
        }
    },
    DireBlast = {
        SkillInfo = {
            { 1, "PetDireBlast", 20.1, "Ranged", 95 }
        }
    },
    DragonBlast = {
        SkillInfo = {
            { 3, "PetAlphaDragon", 20.1, "Ranged", 95 }
        }
    },
    FrontalFire = {
        SkillInfo = {
            { 5, "AetherPet", 30.1, "Ranged", 95 }
        }
    },
    MiseryFire = {
        SkillInfo = {
            { 5, "MiseryPet", 30.1, "Ranged", 95 }
        }
    },
    Unknown = {
        SkillInfo = {
            { 5, "MiseryPet", 30.1, "Ranged", 95 }
        }
    },
    CerberusFire = {
        SkillInfo = {
            { 5, "CerberusFire", 30.1, "Ranged", 95 }
        }
    },
    Wildfire = {
        SkillInfo = { 
            { 5, "WildfirePet", 30.1, "Ranged", 95 }
        }
    },
    SkeletalSlash = {
        SkillInfo = {
            { 6, "SkeletalSlash", 30.1, "Ranged", 95 }
        }
    },
    DeathSlash = {
        SkillInfo = {
            { 6, "DeathSlash", 30.1, "Ranged", 95 }
        }
    },
    HoodedSlash = {
        SkillInfo = { 
             { 1, "HoodedSlash", 30.1, "Ranged", 95 }
        }
    },
    HoodedSlashPoison = {
        SkillInfo = {
            { 1, "HoodedSlashPoison", 25.1, "Ranged", 95 }
        }
    },
    PoisonBreath = {
        SkillInfo = {
            { 3, "PetPoisonBreath", 20.1, "Ranged", 95 }
        }
    },
    TetheredHeal = {
        SkillInfo = { 
             { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    Barrier = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    CrystalBarrier = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    BlackHole = {
        SkillInfo = {
            { 10, "PetBlackHole", 30.1, "Ranged", 95 }
        }
    },
    BlackHolePumpkin = {
        SkillInfo = {
            { 10, "PetBlackHolePumpkin", 30.1, "Ranged", 95 }
        }
    },
    BlackHoleBlazing = {
        SkillInfo = {
            { 10, "PetBlackHoleBlazing", 30.1, "Ranged", 95 }
        }
    },
    BlackHoleCabbage = {
        SkillInfo = {
            { 10, "PetBlackHoleCabbage", 30.1, "Ranged", 95 }
        }
    },
    MeteorStrike = {
        SkillInfo = {
            { 8, "PetMeteorStrike", 25.1, "Ranged", 95 }
        }
    },
    AlienStrike = {
        SkillInfo = {
            { 8, "PetAlienStrike", 25.1, "Ranged", 95 }
        }
    },
    UltRing = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    UltRingGalactic = {
        SkillInfo = {
            { 6, "PetGalactic", 25.1, "Ranged", 95 }
        }
    },
    EquinoxMist = {
        SkillInfo = {
            { 1, "PlayerPosition", 40.1, "Self", 95 }
        }
    },
    RollingJimothy = {
        SkillInfo = {
            { 4, "Jimothy", 20.1, "Ranged", 95 }
        }
    },
    BlackSheepAttack = {
        SkillInfo = {
            { 4, "BlackSheep", 20.1, "Ranged", 95 }
        }
    },
    PinkSheepAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    PurpleDragonAttack = {
        SkillInfo = {
            { 2, "PurpleDragon", 15.1, "Ranged", 95 }
        }
    },
    CyberBeamAttack = {
        SkillInfo = {
            { 2, "CyberBeam", 15.1, "Ranged", 95 }
        }
    },
    RedDragonAttack = {
        SkillInfo = {
            { 7, "RedDragon", 25.1, "Ranged", 95 }
        }
    },
    HellhoundAttack = {
        SkillInfo = {
            { 2, "HellhoundAttack", 15.1, "Ranged", 95 }
        }
    },
    PumpkinAttack = {
        SkillInfo = {
            { 1, "PumpkinAttack", 20.1, "Ranged", 95 }
        }
    },
    CupidPetShockwave = {
        SkillInfo = {
            { 1, "CupidPetShockwave", 25.1, "Ranged", 95 }
        }
    },
    SkeledileAttack = {
        SkillInfo = {
            { 9, "SkeledileAttack", 20.1, "Ranged", 95 }
        }
    },
    Whirlpool = {
        SkillInfo = {
            { 8, "WhirlpoolSmall", 25.1, "Ranged", 95 }
        }
    },
    WhirlpoolIce = {
        SkillInfo = {
            { 8, "WhirlpoolSmallIce", 20.1, "Ranged", 95 }
        }
    },
    HealReach = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    HealReachPro = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    RockAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    BeeAttack = {
        SkillInfo = {
            { 1, "BeeAttack", 20.1, "Ranged", 95 }
        }
    },
    BeeAttackPro = {
        SkillInfo = {
            { 4, "BeeAttack", 15.1, "Ranged", 95 }
        }
    },
    CatAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    CatAttackPro = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GoldenRoad = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GlyphAttack = {
        SkillInfo = {
            { 1, "Bite", 25.1, "Ranged", 95 },
            { 3, {"PetFireball", "PetFireballBlast", "PetIcySpikes"}, 25.1, "Ranged", 95 }
        }
    },
    GlyphAttackPro = {
        SkillInfo = {
            { 10, "PetBlackHole", 20.1, "Ranged", 95 },
            { 3, {"PetFireball", "PetFireballBlast", "PetIcySpikes"}, 20.1, "Ranged", 95 }
        }
    },
    FlameProtection = {
        SkillInfo = {
            { 6, "FlameProtection", 20.1, "Ranged", 95 }
        }
    },
    FlameProtectionPurple = {
        SkillInfo = {
            { 3, "FlameProtectionPurple", 20.1, "Ranged", 95 }
        }
    },
    AvatarFlameProtection = {
        SkillInfo = {
            { 3, "AvatarProtection", 20.1, "Ranged", 95 }
        }
    },
    PurpleSheepAttack = {
        SkillInfo = {
            { 4, "PurpleSheep", 20.1, "Ranged", 95 }
        }
    },
    MegaBite = {
        SkillInfo = {
            { 1, "MegaBite", 15.1, "Ranged", 95 }
        }
    },
    MegaBitePro = {
        SkillInfo = {
            { 1, "MegaBitePro", 15.1, "Ranged", 95 }
        }
    },
    ChocolateSplash = {
        SkillInfo = {
            { 5, "ChocolateSplash", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplash = {
        SkillInfo = {
            { 5, "SlimeSplash", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashInk = {
        SkillInfo = {
            { 5, "InkSlimeSplash", 20.1, "Ranged", 95 }
        }
    },
    SlimeSplashFire = {
        SkillInfo = {
            { 5, "SlimeSplashFire", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashPoison = {
        SkillInfo = {
            { 5, "SlimeSplashPoison", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashIce = {
        SkillInfo = {
            { 5, "SlimeSplashIce", 30.1, "Ranged", 95 }
        }
    },
    Cure = {
        SkillInfo = {
            { 1, "PlayerPosition", 15.1, "Self", 95 }
        }
    },
    CurePro = {
        SkillInfo = {
            { 1, "PlayerPosition", 15.1, "Self", 95 }
        }
    },
    Snowstorm = {
        SkillInfo = {
            { 16, "PetSnowstorm", 30.1, "Ranged", 95 }
        }
    },
    CarrotStorm = {
        SkillInfo = {
            { 20, "PetCarrotStorm", 30.1, "Ranged", 95 }
        }
    },
    ShadowEssence  = {
        SkillInfo = {
            { 20, "ShadowEssence", 30.1, "Ranged", 95 }
        }
    },
    AntiStorm = {
        SkillInfo = {
            { 10, "PetAntiStorm", 30.1, "Ranged", 95 }
        }
    },
    ShiningCrystal = {
        SkillInfo = {
            { 1, "ShiningCrystal", 20.1, "Ranged", 95 }
        }
    },
    ShiningCrystalPro = {
        SkillInfo = { 
            { 1, "ShiningCrystalPro", 20.1, "Ranged", 95 }
        }
    },
    CharmingHeart = {
        SkillInfo = {
            { 4, "CharmingHeart", 25.1, "Ranged", 95 }
        }
    },
    CharmingBrokenHeart = {
        SkillInfo = {
            { 4, "CharmingBrokenHeart", 25.1, "Ranged", 95 }
        }
    },
    CharmingHeartHeal = {
        SkillInfo = {
            { 4, "CharmingHeartHeal", 25.1, "Ranged", 95 }
        }
    },
    CharmingSnowflake  = {
        SkillInfo = {
            { 4, "CharmingSnowflake", 25.1, "Ranged", 95 }
        }
    },
    SpiritBeam = {
        SkillInfo = { 
            { 5, "SpiritBeam", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamFire = {
        SkillInfo = {
            { 5, "SpiritBeamFire", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamAether = {
        SkillInfo = {
            { 5, "SpiritBeamAether", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamPoison = {
        SkillInfo = {
            { 5, "SpiritBeamPoison", 20.1, "Ranged", 95 }
        }
    },
    NaughtyOrNice = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    TurkeyFoodDrop = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    PenguinSlide = {
        SkillInfo = {
            { 8, "PenguinSlide", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Aether = {
        SkillInfo = {
            { 8, "PenguinSlide_Aether", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Frozen = {
        SkillInfo = {
            { 8, "PenguinSlide_Frozen", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Burn = {
        SkillInfo = {
            { 8, "PenguinSlide_Burn", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Poison = {
        SkillInfo = {
            { 8, "PenguinSlide_Poison", 30.1, "Ranged", 95 }
        }
    },
    GMMoAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GMRodAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GMKnoxAttack = {
        SkillInfo = {
            { 1, "KnoxAttack", 25.1, "Ranged", 95 }
        }
    },
    FireballDH = {
        SkillInfo = {
            { 8, "PetFireballDH", 15.1, "Ranged", 95 },
            { 2, {"PetFireball", "PetFireballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    GargoyleSkill = {
        SkillInfo = {
            { 5, "GargoyleSkill", 30.1, "Ranged", 95 }
        }
    },
    MoltenGolemAttack = {
        SkillInfo = {
            { 4, "MoltenGolemAttack", 25.1, "Ranged", 95 }
        }
    },
    EvilClownSkill = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "MobPosition", 95 }
        }
    },
    TrippleFireball = {
        SkillInfo = {
            { 3, "PetFireball", 15.1, "Ranged", 95, SkipFirst = true },
            { 3, "PetFireballBlast", 15.1, "Ranged", 95, SkipFirst = true }
        }
    },
    IceShards = {
        SkillInfo = {
            { 5, "PetIceShards", 15.1, "Ranged", 95 }
        }
    },
    ToxicThorns = {
        SkillInfo = {
            { 4, "PetToxicThorns", 20.1, "Ranged", 95 }
        }
    },
    IgnisDragonPetAttack = {
        SkillInfo = {
            { 8, "IgnisDragonPetAttack", 15.1, "Ranged", 95 }
        }
    },
    RuinousDragonPetAttack = {
        SkillInfo = {
            { 8, "RuinousDragonPetAttack", 15.1, "Ranged", 95 }
        }
    },
    PinataParty = {
        SkillInfo = {
            { 10, "PetPinataParty", 20.1, "Ranged", 95 }
        }
    },
    NoobTornado = {
        SkillInfo = {
            { 8, "PetNoobTornado", 25.1, "Ranged", 95 }
        }
    }
}

return PetData
