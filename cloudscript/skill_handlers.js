// skill_handlers.js — PlayFab CloudScript handler for skill data sync
// Register this handler on PlayFab: handlers.syncSkillData = syncSkillData;

handlers.syncSkillData = function (args, context) {
    var characterId = args.characterId || currentPlayerId;
    var equippedSkill = args.equippedSkill || "";

    // Store equipped skill in Character Internal Data
    var updateRequest = {
        PlayFabId: currentPlayerId,
        CharacterId: characterId,
        Data: {
            "EquippedSkill": equippedSkill
        }
    };

    var result = server.UpdateCharacterInternalData(updateRequest);

    return {
        success: true,
        equippedSkill: equippedSkill
    };
};

// NOTE: The existing getCharacterInventory handler should also return
// the EquippedSkill field from Character Internal Data so the client
// can restore it on login. Add this to the existing handler:
//
//   var skillData = server.GetCharacterInternalData({
//       PlayFabId: currentPlayerId,
//       CharacterId: characterId,
//       Keys: ["EquippedSkill"]
//   });
//   response.equippedSkill = (skillData.Data && skillData.Data.EquippedSkill)
//       ? skillData.Data.EquippedSkill.Value
//       : "";
