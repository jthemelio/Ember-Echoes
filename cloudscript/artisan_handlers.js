// ═══════════════════════════════════════════════════════════════
// Artisan CloudScript Handlers
// Server-side validation for Ignis composition and scroll conversion.
//
// All materials are now inventory items (stored in Inv_Bag on
// Character Internal Data). These handlers validate and mutate
// the bag server-side to prevent client-side cheating.
//
// Handlers:
//   composeIgnis    — 3x Ignis +N  → 1x Ignis +(N+1)
//   compressScroll  — 10x single   → 1x scroll
//   expandScroll    — 1x scroll    → 10x singles
// ═══════════════════════════════════════════════════════════════

// ── Constants ──
var IGNIS_TIERS = [
    "ignis_plus_1", "ignis_plus_2", "ignis_plus_3",
    "ignis_plus_4", "ignis_plus_5", "ignis_plus_6"
];

var SCROLL_PAIRS = {
    "Comet":       { single: "Comet",       scroll: "Comet_Scroll" },
    "Wyrm_Sphere": { single: "Wyrm_Sphere", scroll: "Wyrm_Sphere_Scroll" }
};

// ── Helpers ──

function readInventoryBag(playFabId, characterId) {
    var result = server.GetCharacterInternalData({
        PlayFabId: playFabId,
        CharacterId: characterId,
        Keys: ["Inv_Bag"]
    });
    if (result.Data && result.Data.Inv_Bag) {
        try {
            return JSON.parse(result.Data.Inv_Bag.Value);
        } catch (e) {
            return [];
        }
    }
    return [];
}

function writeInventoryBag(playFabId, characterId, bag) {
    server.UpdateCharacterInternalData({
        PlayFabId: playFabId,
        CharacterId: characterId,
        Data: { Inv_Bag: JSON.stringify(bag) }
    });
}

function countByBid(bag, bid) {
    var total = 0;
    for (var i = 0; i < bag.length; i++) {
        if (bag[i].bid === bid) {
            var amt = bag[i].amt || 1;
            total += amt;
        }
    }
    return total;
}

function removeByBid(bag, bid, count) {
    var remaining = count;
    for (var i = bag.length - 1; i >= 0 && remaining > 0; i--) {
        if (bag[i].bid !== bid) continue;
        var stack = bag[i].amt || 1;
        if (stack <= remaining) {
            remaining -= stack;
            bag.splice(i, 1);
        } else {
            bag[i].amt = stack - remaining;
            remaining = 0;
        }
    }
    return remaining === 0;
}

function generateUid() {
    return "m_" + Math.random().toString(36).substr(2, 10);
}

function createMaterialInstance(bid) {
    return {
        uid: generateUid(),
        bid: bid,
        q: "Normal",
        plus: 0,
        skt: [],
        ench: {},
        dura: 0
    };
}

// ═══════════════════════════════════════════════════════════════
// Handler: composeIgnis
// args: { CharacterId, tierBid }
// Consumes 3x tierBid, adds 1x next tier.
// ═══════════════════════════════════════════════════════════════
handlers.composeIgnis = function (args, context) {
    var playFabId = currentPlayerId;
    var characterId = args.CharacterId;
    var tierBid = args.tierBid;

    if (!characterId || !tierBid) {
        return { success: false, error: "Missing CharacterId or tierBid" };
    }

    // Validate tier
    var tierIndex = IGNIS_TIERS.indexOf(tierBid);
    if (tierIndex < 0 || tierIndex >= IGNIS_TIERS.length - 1) {
        return { success: false, error: "Invalid or max tier: " + tierBid };
    }
    var nextBid = IGNIS_TIERS[tierIndex + 1];

    // Read bag
    var bag = readInventoryBag(playFabId, characterId);
    var count = countByBid(bag, tierBid);
    if (count < 3) {
        return { success: false, error: "Not enough " + tierBid + " (have " + count + ", need 3)" };
    }

    // Remove 3, add 1 next tier
    removeByBid(bag, tierBid, 3);
    bag.push(createMaterialInstance(nextBid));

    // Save
    writeInventoryBag(playFabId, characterId, bag);

    log.info("composeIgnis: " + tierBid + " x3 -> " + nextBid + " x1 for " + playFabId);
    return {
        success: true,
        consumed: tierBid,
        produced: nextBid,
        newCount: countByBid(bag, nextBid)
    };
};

// ═══════════════════════════════════════════════════════════════
// Handler: compressScroll
// args: { CharacterId, materialType } — "Comet" or "Wyrm_Sphere"
// Consumes 10x singles, adds 1x scroll.
// ═══════════════════════════════════════════════════════════════
handlers.compressScroll = function (args, context) {
    var playFabId = currentPlayerId;
    var characterId = args.CharacterId;
    var materialType = args.materialType;

    if (!characterId || !materialType) {
        return { success: false, error: "Missing CharacterId or materialType" };
    }

    var pair = SCROLL_PAIRS[materialType];
    if (!pair) {
        return { success: false, error: "Invalid materialType: " + materialType };
    }

    var bag = readInventoryBag(playFabId, characterId);
    var singleCount = countByBid(bag, pair.single);
    if (singleCount < 10) {
        return { success: false, error: "Not enough " + pair.single + " (have " + singleCount + ", need 10)" };
    }

    removeByBid(bag, pair.single, 10);
    bag.push(createMaterialInstance(pair.scroll));

    writeInventoryBag(playFabId, characterId, bag);

    log.info("compressScroll: 10x " + pair.single + " -> 1x " + pair.scroll + " for " + playFabId);
    return {
        success: true,
        consumed: pair.single,
        produced: pair.scroll,
        newScrollCount: countByBid(bag, pair.scroll)
    };
};

// ═══════════════════════════════════════════════════════════════
// Handler: expandScroll
// args: { CharacterId, materialType } — "Comet" or "Wyrm_Sphere"
// Consumes 1x scroll, adds 10x singles.
// ═══════════════════════════════════════════════════════════════
handlers.expandScroll = function (args, context) {
    var playFabId = currentPlayerId;
    var characterId = args.CharacterId;
    var materialType = args.materialType;

    if (!characterId || !materialType) {
        return { success: false, error: "Missing CharacterId or materialType" };
    }

    var pair = SCROLL_PAIRS[materialType];
    if (!pair) {
        return { success: false, error: "Invalid materialType: " + materialType };
    }

    var bag = readInventoryBag(playFabId, characterId);
    var scrollCount = countByBid(bag, pair.scroll);
    if (scrollCount < 1) {
        return { success: false, error: "No " + pair.scroll + " available" };
    }

    removeByBid(bag, pair.scroll, 1);
    for (var i = 0; i < 10; i++) {
        bag.push(createMaterialInstance(pair.single));
    }

    writeInventoryBag(playFabId, characterId, bag);

    log.info("expandScroll: 1x " + pair.scroll + " -> 10x " + pair.single + " for " + playFabId);
    return {
        success: true,
        consumed: pair.scroll,
        produced: pair.single,
        newSingleCount: countByBid(bag, pair.single)
    };
};
