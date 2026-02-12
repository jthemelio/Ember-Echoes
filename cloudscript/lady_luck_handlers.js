// ═══════════════════════════════════════════════════════════════
// Lady Luck CloudScript Handlers  (v2 — pay-then-pick flow)
// Add these to your PlayFab CloudScript (revision)
//
// Flow:
//   1. getLadyLuckStatus  → UI balances + free-roll timer
//   2. ladyLuckRoll       → deducts payment, generates 9 rewards,
//                            stores in PendingLadyLuck, returns {paid:true}
//   3. ladyLuckClaim      → takes chosenIndex (0-8), grants that
//                            reward, clears pending, returns all 9
//
// NOTE: Lottery Tickets (LT) are stored in Internal Data (not
// VirtualCurrency) because PlayFab Legacy has a 10-currency cap.
// Key: "LotteryTickets" (integer stored as string)
// ═══════════════════════════════════════════════════════════════

// ── Reward Table ──
// All rewards are type:"item" (handled client-side). No server-side currency granting.
// Total weight: ~200.6  (adjust as needed)
var LADY_LUCK_REWARDS = [
    // --- Money Bag Progression (Class 1-10) ---
    { type: "item", id: "money_bag_1",  quantity: 1, weight: 25,   name: "Class 1 Pouch" },
    { type: "item", id: "money_bag_2",  quantity: 1, weight: 20,   name: "Class 2 Pouch" },
    { type: "item", id: "money_bag_3",  quantity: 1, weight: 15,   name: "Class 3 Sack" },
    { type: "item", id: "money_bag_4",  quantity: 1, weight: 12,   name: "Class 4 Sack" },
    { type: "item", id: "money_bag_5",  quantity: 1, weight: 10,   name: "Class 5 Chest" },
    { type: "item", id: "money_bag_6",  quantity: 1, weight: 8,    name: "Class 6 Chest" },
    { type: "item", id: "money_bag_7",  quantity: 1, weight: 6,    name: "Class 7 Treasury" },
    { type: "item", id: "money_bag_8",  quantity: 1, weight: 4,    name: "Class 8 Treasury" },
    { type: "item", id: "money_bag_9",  quantity: 1, weight: 2,    name: "Class 9 Royal Coffer" },
    { type: "item", id: "money_bag_10", quantity: 1, weight: 1,    name: "Class 10 Imperial Hoard" },

    // --- Ignis Upgrade Materials (+1 common → +6 ultra rare) ---
    { type: "item", id: "ignis_plus_1", quantity: 1, weight: 20,   name: "+1 Ignis" },
    { type: "item", id: "ignis_plus_2", quantity: 1, weight: 10,   name: "+2 Ignis" },
    { type: "item", id: "ignis_plus_3", quantity: 1, weight: 5,    name: "+3 Ignis" },
    { type: "item", id: "ignis_plus_4", quantity: 1, weight: 1,    name: "+4 Ignis" },
    { type: "item", id: "ignis_plus_5", quantity: 1, weight: 0.2,  name: "+5 Ignis" },
    { type: "item", id: "ignis_plus_6", quantity: 1, weight: 0.05, name: "+6 Ignis" },

    // --- Comets & Wyrm Spheres ---
    { type: "item", id: "comet_stone",          quantity: 1, weight: 15,   name: "Comet" },
    { type: "item", id: "wyrm_sphere_artifact", quantity: 1, weight: 5,    name: "Wyrm Sphere" },

    // --- Scrolls (very rare) ---
    { type: "item", id: "comet_scroll",       quantity: 1, weight: 0.5,  name: "Comet Scroll" },
    { type: "item", id: "wyrm_sphere_scroll", quantity: 1, weight: 0.15, name: "Wyrm Sphere Scroll" },

    // --- Gemstones ---
    { type: "item", id: "gem_drake_radiant",   quality: "Radiant", quantity: 1, weight: 1, name: "Radiant Drake Heartstone" },
    { type: "item", id: "gem_phoenix_radiant", quality: "Radiant", quantity: 1, weight: 1, name: "Radiant Ember Talon" },
    { type: "item", id: "gem_unicorn_radiant", quality: "Radiant", quantity: 1, weight: 1, name: "Radiant Unicorn Shard" },

    // --- High-End Equipment (extremely rare) ---
    { type: "item", id: "boots_10", level: 10, quality: "Brilliant", sockets: 2, quantity: 1, weight: 0.1, name: "Brilliant 2-Socket Boots" },
    { type: "item", id: "bs_10",    level: 10, quality: "Brilliant", sockets: 2, quantity: 1, weight: 0.1, name: "Brilliant 2-Socket Mageblade" }
];

var LUCKY_PET_CHANCE = 1.0 / 2000.0;
var FREE_ROLL_COOLDOWN_MS = 3600000; // 1 hour in milliseconds
var ECHO_COST = 50; // Echo Points per roll

// ── Weighted Random Roll ──
function rollWeightedReward() {
    var totalWeight = 0;
    for (var i = 0; i < LADY_LUCK_REWARDS.length; i++) {
        totalWeight += LADY_LUCK_REWARDS[i].weight;
    }
    var roll = Math.random() * totalWeight;
    var cumulative = 0;
    for (var i = 0; i < LADY_LUCK_REWARDS.length; i++) {
        cumulative += LADY_LUCK_REWARDS[i].weight;
        if (roll < cumulative) {
            return LADY_LUCK_REWARDS[i];
        }
    }
    return LADY_LUCK_REWARDS[LADY_LUCK_REWARDS.length - 1];
}

// ── Helper: read LT balance from Internal Data ──
function getLotteryTickets(playFabId) {
    var data = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["LotteryTickets"]
    });
    if (data.Data && data.Data.LotteryTickets) {
        return parseInt(data.Data.LotteryTickets.Value, 10) || 0;
    }
    return 0;
}

// ── Helper: set LT balance in Internal Data ──
function setLotteryTickets(playFabId, amount) {
    server.UpdateUserInternalData({
        PlayFabId: playFabId,
        Data: { LotteryTickets: String(Math.max(0, amount)) }
    });
}

// ── Helper: build a display-safe reward object (no granting) ──
function rewardToDisplay(reward) {
    var r = { id: reward.id, name: reward.name, type: reward.type };
    if (reward.quantity)     r.quantity     = reward.quantity;
    if (reward.quality)      r.quality      = reward.quality;
    if (reward.sockets)      r.sockets      = reward.sockets;
    if (reward.level)        r.level        = reward.level;
    if (reward.currencyCode) r.currencyCode = reward.currencyCode;
    return r;
}

// ═══════════════════════════════════════════════════════════════
// Handler: getLadyLuckStatus
// Returns free roll availability, LT balance, currency balances,
// and whether there is a pending (unclaimed) roll.
// ═══════════════════════════════════════════════════════════════
handlers.getLadyLuckStatus = function (args, context) {
    var playFabId = currentPlayerId;

    var internalData = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["LastFreeRollTimestamp", "LotteryTickets", "PendingLadyLuck"]
    });

    var freeRollAvailable = true;
    var msUntilFree = 0;
    var lotteryTickets = 0;
    var hasPending = false;

    if (internalData.Data) {
        if (internalData.Data.LastFreeRollTimestamp) {
            var lastTime = new Date(internalData.Data.LastFreeRollTimestamp.Value).getTime();
            var elapsed = Date.now() - lastTime;
            if (elapsed < FREE_ROLL_COOLDOWN_MS) {
                freeRollAvailable = false;
                msUntilFree = FREE_ROLL_COOLDOWN_MS - elapsed;
            }
        }
        if (internalData.Data.LotteryTickets) {
            lotteryTickets = parseInt(internalData.Data.LotteryTickets.Value, 10) || 0;
        }
        if (internalData.Data.PendingLadyLuck) {
            hasPending = true;
        }
    }

    var inventory = server.GetUserInventory({ PlayFabId: playFabId });
    var currencies = inventory.VirtualCurrency || {};

    return {
        success: true,
        freeRollAvailable: freeRollAvailable,
        msUntilFree: msUntilFree,
        lotteryTickets: lotteryTickets,
        hasPending: hasPending,
        currencies: {
            ET: currencies.ET || 0,
            GD: currencies.GD || 0
        }
    };
};

// ═══════════════════════════════════════════════════════════════
// Handler: ladyLuckRoll  (Step 1 — Pay)
// Validates payment, generates 9 rewards, stores them in
// PendingLadyLuck.  Does NOT grant any reward yet.
// paymentMethod: "free" | "ticket" | "echo"
// ═══════════════════════════════════════════════════════════════
handlers.ladyLuckRoll = function (args, context) {
    var playFabId = currentPlayerId;
    var paymentMethod = args.paymentMethod || "free";

    // Block if there is already a pending (unclaimed) roll
    var pendingCheck = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["PendingLadyLuck"]
    });
    if (pendingCheck.Data && pendingCheck.Data.PendingLadyLuck) {
        return { success: false, error: "You have an unclaimed roll. Pick a chest first!" };
    }

    // ── Validate Payment ──
    if (paymentMethod === "free") {
        var internalData = server.GetUserInternalData({
            PlayFabId: playFabId,
            Keys: ["LastFreeRollTimestamp"]
        });
        if (internalData.Data && internalData.Data.LastFreeRollTimestamp) {
            var lastTime = new Date(internalData.Data.LastFreeRollTimestamp.Value).getTime();
            if (Date.now() - lastTime < FREE_ROLL_COOLDOWN_MS) {
                return { success: false, error: "Free roll not available yet" };
            }
        }
        server.UpdateUserInternalData({
            PlayFabId: playFabId,
            Data: { LastFreeRollTimestamp: new Date().toISOString() }
        });

    } else if (paymentMethod === "ticket") {
        var ltBalance = getLotteryTickets(playFabId);
        if (ltBalance < 1) {
            return { success: false, error: "Not enough Lottery Tickets" };
        }
        setLotteryTickets(playFabId, ltBalance - 1);

    } else if (paymentMethod === "echo") {
        var inv = server.GetUserInventory({ PlayFabId: playFabId });
        var etBalance = (inv.VirtualCurrency && inv.VirtualCurrency.ET) || 0;
        if (etBalance < ECHO_COST) {
            return { success: false, error: "Not enough Echo Points (need " + ECHO_COST + ")" };
        }
        server.SubtractUserVirtualCurrency({
            PlayFabId: playFabId,
            VirtualCurrency: "ET",
            Amount: ECHO_COST
        });
    } else {
        return { success: false, error: "Invalid payment method" };
    }

    // ── Generate 9 rewards ──
    var rewards = [];
    for (var i = 0; i < 9; i++) {
        rewards.push(rollWeightedReward());
    }

    // Store in Internal Data so ladyLuckClaim can read them
    var pending = [];
    for (var i = 0; i < 9; i++) {
        pending.push(rewardToDisplay(rewards[i]));
    }
    server.UpdateUserInternalData({
        PlayFabId: playFabId,
        Data: { PendingLadyLuck: JSON.stringify(pending) }
    });

    // Get updated balances
    var updatedInv = server.GetUserInventory({ PlayFabId: playFabId });
    var updatedCurrencies = updatedInv.VirtualCurrency || {};
    var updatedLT = getLotteryTickets(playFabId);

    // Free-roll status
    var freeData = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["LastFreeRollTimestamp"]
    });
    var newFreeAvailable = true;
    var newMsUntilFree = 0;
    if (freeData.Data && freeData.Data.LastFreeRollTimestamp) {
        var lt = new Date(freeData.Data.LastFreeRollTimestamp.Value).getTime();
        var elapsed = Date.now() - lt;
        if (elapsed < FREE_ROLL_COOLDOWN_MS) {
            newFreeAvailable = false;
            newMsUntilFree = FREE_ROLL_COOLDOWN_MS - elapsed;
        }
    }

    return {
        success: true,
        paid: true,
        freeRollAvailable: newFreeAvailable,
        msUntilFree: newMsUntilFree,
        lotteryTickets: updatedLT,
        currencies: {
            ET: updatedCurrencies.ET || 0,
            GD: updatedCurrencies.GD || 0
        }
    };
};

// ═══════════════════════════════════════════════════════════════
// Handler: ladyLuckClaim  (Step 2 — Pick chest)
// Reads PendingLadyLuck, grants reward at chosenIndex,
// clears pending data, returns all 9 rewards + lucky pet.
// args: { chosenIndex: 0-8 }
// ═══════════════════════════════════════════════════════════════
handlers.ladyLuckClaim = function (args, context) {
    var playFabId = currentPlayerId;
    var chosenIndex = args.chosenIndex;

    if (chosenIndex === undefined || chosenIndex === null || chosenIndex < 0 || chosenIndex > 8) {
        return { success: false, error: "Invalid chest index (0-8)" };
    }

    // Read pending rewards
    var pendingData = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["PendingLadyLuck"]
    });
    if (!pendingData.Data || !pendingData.Data.PendingLadyLuck) {
        return { success: false, error: "No pending roll found. Pay first!" };
    }

    var rewards;
    try {
        rewards = JSON.parse(pendingData.Data.PendingLadyLuck.Value);
    } catch (e) {
        return { success: false, error: "Corrupted pending data" };
    }

    if (!rewards || rewards.length !== 9) {
        return { success: false, error: "Invalid pending data" };
    }

    // All rewards are type:"item" now — handled client-side
    // (added to inventory: gold bags, materials, gemstones, equipment)
    var chosen = rewards[chosenIndex];

    // Lucky Pet roll (independent 1/2000)
    var luckyPet = null;
    if (Math.random() < LUCKY_PET_CHANCE) {
        luckyPet = "Lucky Lady";
    }

    // Clear pending data
    server.UpdateUserInternalData({
        PlayFabId: playFabId,
        Data: { PendingLadyLuck: null }  // null removes the key
    });

    // Updated balances
    var updatedInv = server.GetUserInventory({ PlayFabId: playFabId });
    var updatedCurrencies = updatedInv.VirtualCurrency || {};
    var updatedLT = getLotteryTickets(playFabId);

    // Free-roll status
    var freeData = server.GetUserInternalData({
        PlayFabId: playFabId,
        Keys: ["LastFreeRollTimestamp"]
    });
    var freeAvailable = true;
    var msUntilFree = 0;
    if (freeData.Data && freeData.Data.LastFreeRollTimestamp) {
        var lt = new Date(freeData.Data.LastFreeRollTimestamp.Value).getTime();
        var elapsed = Date.now() - lt;
        if (elapsed < FREE_ROLL_COOLDOWN_MS) {
            freeAvailable = false;
            msUntilFree = FREE_ROLL_COOLDOWN_MS - elapsed;
        }
    }

    return {
        success: true,
        rewards: rewards,
        chosenIndex: chosenIndex,
        chosenReward: chosen,
        luckyPet: luckyPet,
        freeRollAvailable: freeAvailable,
        msUntilFree: msUntilFree,
        lotteryTickets: updatedLT,
        currencies: {
            ET: updatedCurrencies.ET || 0,
            GD: updatedCurrencies.GD || 0
        }
    };
};

// ═══════════════════════════════════════════════════════════════
// Handler: addLotteryTickets
// Grants Lottery Tickets (call from admin or other reward systems)
// args: { amount: number }
// ═══════════════════════════════════════════════════════════════
handlers.addLotteryTickets = function (args, context) {
    var playFabId = currentPlayerId;
    var amount = args.amount || 0;
    if (amount <= 0) {
        return { success: false, error: "Amount must be positive" };
    }
    var current = getLotteryTickets(playFabId);
    setLotteryTickets(playFabId, current + amount);
    return {
        success: true,
        newBalance: current + amount
    };
};
