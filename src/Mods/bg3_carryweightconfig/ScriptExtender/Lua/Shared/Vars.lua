-- The mod variable AppliedBoosts of version 1.0.0.0 (it kept the boost each character got). Since 1.0.0.1 the mod
-- changes the global carry values instead and does not use it. It stays registered, with the same settings in both
-- contexts, so that saves made with 1.0.0.0 keep a known variable.

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
