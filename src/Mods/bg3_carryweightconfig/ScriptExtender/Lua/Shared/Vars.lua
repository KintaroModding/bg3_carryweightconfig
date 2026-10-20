-- The mod variable AppliedBoosts lives in the savegame: [character UUID] = the boost text this mod added to that
-- character, so that the next change removes exactly that boost. Only the server reads or writes it. Variables must
-- be registered with the same settings in both contexts, so both bootstrap files load this file.

Ext.Vars.RegisterModVariable(ModuleUUID, "AppliedBoosts", {
    Server = true,
    Client = false,
    WriteableOnServer = true,
    WriteableOnClient = false,
    Persistent = true,
    SyncToClient = false,
    SyncToServer = false,
})

return true
