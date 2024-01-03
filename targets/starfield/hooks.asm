//----------------------------------------------------------------------
// Hooks for Omnified Starfield
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2024 Bad Echo LLC
//
// Bad Echo Technologies are licensed under a
// GNU Affero General Public License v3.0.
//
// See accompanying file LICENSE.md or a copy at:
// https://www.gnu.org/licenses/agpl-3.0.html
//----------------------------------------------------------------------


// Maps a symbol to the actor value key array.
aobscanmodule(omniActorValueKeysHook,Starfield.exe,48 8D 05 ?? ?? ?? ?? 48 83 C4 28 C3 CC 48 89 5C 24 10 48 89 4C 24 08) // should be unique

label(actorValueKeys)
registersymbol(actorValueKeys)

// The actor value keys are found at the static address used as an operand at the injection site.
//      lea rax [Starfield.exe+xxxxxxx]
// This translates to the byte code:
//      48 8D 05 XX XX XX XX
// In order to map our symbol to this static address, we:
// 1) Skip the first three bytes (they are the instruction and first operand [rax])
// 2) Read a DWORD's worth of memory to get the address offset (from the current instruction).
// 3) Add this offset to the address of the instruction.
// 4) Add another 7 bytes (since the instruction at the injection site is 7 bytes long).
// 
// Each actor value key found in this array correspond with a particular ActorValueInfo type. In order to look up the value of an ActorValueInfo type for a particular NPC,
// iterate through the property bag found in the entity's structure for entries pointing to the particular key. Each key seems to have a hardcoded identifier, known ones
// will be listed here.
//
// ActorValueInfo types are structured as having a base type, with no modifiers, linked to an effective value type with modifiers applied. 
// The effective value type is located at [[actorValueInfo+0xA8]+x0]
//
// Known ActorValueInfo Types:
//  Maximum Oxygen - 0x8
//  Ship Hull Offset (base type at root) / Maximum Health - 0x108
omniActorValueKeysHook+(DWORD)[omniActorValueKeysHook+3]+7:
actorValueKeys:


// Maps a symbol to the ship shield offset actor value key.
aobscanmodule(omniActorValueKeyShieldHook,Starfield.exe,48 8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 8B F0 4C 3B C0)

label(actorValueKeyShield)
registersymbol(actorValueKeyShield)

// The same approach taken above is used to map the ship shield actor value key to a symbol.
omniActorValueKeyShieldHook+(DWORD)[omniActorValueKeyShieldHook+3]+7:
actorValueKeyShield:


// Searches for and returns the value for an ActorValueInfo type.
// [rsp+18]: The max ActorValueInfo entry address to check.
// [rsp+20]: The start of the ActorValueInfo property bag.
// [rsp+28]: The base ActorValueInfo type key.
// Return value is in RAX.
// In order to find effective ActorValueInfo values, we iterate through all entries in the ActorValueInfo property bag for a matching key 
// at [entry+0x0]. Each entry is 16 bytes. Value is at matched [entry+0x8].
alloc(getActorValue,$1000)

registersymbol(getActorValue)

getActorValue:
    // Load the effective ActorValueInfo type.    
    push rbx
    push rdx    
    mov rax,[rsp+28]
    mov rbx,[rax+A8]
    mov rax,[rbx]
    mov rbx,[rsp+20]
    mov rdx,[rsp+18]
nextActorValue:
    // Check if we're past the last ActorValueInfo entry.
    cmp rbx,rdx
    jg getActorValueExit
    push rcx
    lea rcx,[rbx]
    call checkBadPointer
    cmp rcx,0
    pop rcx
    jne getActorValueExit
    cmp rax,[rbx]    
    je readActorValue
    add rbx,10
    jmp nextActorValue
readActorValue:
    mov rax,[rbx+8]
getActorValueExit:
    pop rdx
    pop rbx
    ret 18

// Gets the identifier for the PlayerCharacter type.
// [r14]: Contains the type identifier for PlayerCharacter.
aobscanmodule(omniPlayerCharacterTypeHook,Starfield.exe,49 8B 06 49 8B CE ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? FF 90 C0 04 00 00)

alloc(getPlayerCharacterType,$1000,omniPlayerCharacterTypeHook)
alloc(playerCharacterType,8)

registersymbol(playerCharacterType)
registersymbol(omniPlayerCharacterTypeHook)

getPlayerCharacterType:
    pushf
    cmp rsi,1
    je getPlayerCharacterTypeOriginalCode
    push rax
    mov rax,[r14]
    mov [playerCharacterType],rax
    pop rax
getPlayerCharacterTypeOriginalCode:
    popf
    mov rax,[r14]
    mov rcx,r14
    jmp getPlayerCharacterTypeReturn

omniPlayerCharacterTypeHook:
    jmp getPlayerCharacterType
    nop
getPlayerCharacterTypeReturn:

// Gets the player's root structure.
// Effective health is located at [player]+0x398 -- it is stored as an offset (seems to be either 0 or a negative value, which you add to the maximum health to get your health).
// Effective oxygen is located at [player]+0x3A4 -- also an offset.
// Maximum health is an ActorValueInfo property whose key value can be found at [[actorValueKeys+0x108]+0xA8]+x0]
// In order to find ActorValueInfo values, search in [player]+0x280, for specific key at [entry+0x0] every 16 bytes. Value is at matched [entry+0x8].
// rcx: The player's root PlayerCharacter structure. Rarely, this is a TESObjectREFR, which we should ignore. 
// UNIQUE AOB: 48 8B 01 48 8B FA 33 DB FF 90 E0
define(omniPlayerHook,"Starfield.exe"+1A0FC9E)

assert(omniPlayerHook,48 8B 01 48 8B FA)
alloc(getPlayer,$1000,omniPlayerHook)
alloc(player,8)
alloc(playerHealth,8)
alloc(playerMaxHealth,8)
alloc(playerMaxOxygen,8)
alloc(playerOxygen,8)
alloc(playerMaxEquipLoad,8)

registersymbol(playerMaxEquipLoad)
registersymbol(playerOxygen)
registersymbol(playerMaxOxygen) 
registersymbol(playerHealth)
registersymbol(playerMaxHealth)
registersymbol(player)
registersymbol(omniPlayerHook)

getPlayer:
    pushf
    sub rsp,10
    movdqu [rsp],xmm0
    push rax
    push rbx
    push rdx
    // Only allow PlayerCharacter type structures.
    mov rax,playerCharacterType
    mov rbx,[rcx]
    cmp [rax],rbx
    jne getPlayerExit
    mov [player],rcx        
    // Calculate the max ActorValueInfo entry address to check based on the number of entries stored at [player]+0x278.
    mov eax,[rcx+278]
    mov rdx,10
    mul rdx
    add rax,[rcx+280]
    mov rbx,rax    
    // Find the maximum health value.
    push [actorValueKeys+108]
    push [rcx+280]
    push rbx
    call getActorValue
    mov [playerMaxHealth],rax
    // Find the maximum oxygen value.
    push [actorValueKeys+8]
    push [rcx+280]
    push rbx
    call getActorValue
    mov [playerMaxOxygen],rax 
    // Calculate display values for current health and oxygen.
    movss xmm0,[rcx+398]
    addss xmm0,[playerMaxHealth]
    movss [playerHealth],xmm0
    movss xmm0,[rcx+3A4]
    addss xmm0,[playerMaxOxygen]
    movss [playerOxygen],xmm0
    // Create a pointer to the player's max equip load.
    mov rbx,[rcx+240]
    mov rdx,[rbx+58]
    mov rbx,[rdx+40]
    // playerMaxEquipLoad value will be at [rbx+68]
    mov [playerMaxEquipLoad],rbx
getPlayerExit:
    pop rdx
    pop rbx
    pop rax
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerOriginalCode:
    popf
    mov rax,[rcx]
    mov rdi,rdx
    jmp getPlayerReturn

omniPlayerHook:
    jmp getPlayer
    nop 
getPlayerReturn:


// Gets the identifier for the ExtraActorValueStorage type.
// rax: Contains the type identifier for ExtraActorValuesStorage.
aobscanmodule(omniExtraActorValueStorageTypeHook,Starfield.exe,48 89 5C 24 08 57 48 83 EC 20 48 8B F9 8B DA 48 83 C1 18 E8 ?? ?? ?? ?? F6 C3 01 ?? ?? BA 40 00 00 00 48 8B CF E8 ?? ?? ?? ?? 48 8B 5C 24 30 48 8B C7 48 83 C4 20 5F C3 48 89 5C 24 08 57 48 83 EC 20 8B DA)

alloc(getExtraActorValueStorageType,$1000,omniExtraActorValueStorageTypeHook)
alloc(extraActorValuesStorageType,8)

registersymbol(extraActorValuesStorageType)
registersymbol(omniExtraActorValueStorageTypeHook)

getExtraActorValueStorageType:
    mov [extraActorValuesStorageType],rax
getExtraActorValueStorageTypeOriginalCode:
    mov [rsp+08],rbx
    jmp getExtraActorValueStorageTypeReturn

omniExtraActorValueStorageTypeHook:
    jmp getExtraActorValueStorageType
getExtraActorValueStorageTypeReturn:


// Gets the identifier for the ExtraPromotedRef type.
// rax: Contains the type identifier for ExtraPromotedRef.
aobscanmodule(omniExtraPromotedRefTypeHook,Starfield.exe,48 89 5C 24 08 57 48 83 EC 20 8B DA 48 8B F9 E8 ?? ?? ?? ?? F6 C3 01 ?? ?? BA 38 00 00 00 48 8B CF E8 ?? ?? ?? ?? 48 8B 5C 24 30 48 8B C7 48 83 C4 20 5F C3 48 89 5C 24 08 57 48 83 EC 20 8B DA 48 8B F9 E8 ?? ?? ?? ?? F6 C3 01 ?? ?? BA 20 00 00 00 48 8B CF E8 ?? ?? ?? ?? 48 8B 5C 24 30 48 8B C7 48 83 C4 20 5F C3 40 53)

alloc(getExtraPromotedRefType,$1000,omniExtraPromotedRefTypeHook)
alloc(extraPromotedRefType,8)

registersymbol(extraPromotedRefType)
registersymbol(omniExtraPromotedRefTypeHook)

getExtraPromotedRefType:
    mov [extraPromotedRefType],rax
getExtraPromotedRefTypeOriginalCode:
    mov [rsp+08],rbx
    jmp getExtraPromotedRefTypeReturn

omniExtraPromotedRefTypeHook:
    jmp getExtraPromotedRefType
getExtraPromotedRefTypeReturn:


// Gets the address to the ActorValueInfo container for the player's ship.
// rax: Needs to be the ExtraActorValueStorage type to be related to our ship.
// Also, [rax+8] cannot be an ExtraPromotedRef.
// Adjust rax by +18 to make it a working key to match against ship vital pollers.
// UNIQUE AOB: 48 8B 40 08 48 85 C0 75 ?? 41 BE FF FF FF FF 48 85 DB 74 ?? 41 8B CE F0 0F C1 4B 04 8B C1 25 FF 0F C0 FF 83 F8 01 75 ?? F7 C1 00 F0 3F 00 74 ?? 48 8D 4B 04 ?? ?? ?? ?? ?? ?? 48 85 FF ?? ?? ?? ?? ?? ?? 48 8B 84 24 B8 00 00 00 48 8B A8 E0 00 00 00 48 85 ED ?? ?? ?? ?? ?? ?? 45 32 FF 0F BE 45 4F 83 C0 Fb 83 F8 05 ?? ?? ?? ?? ?? ?? 48 98 48 ?? ?? ?? ?? ?? ?? 8B 8C 82 ?? ?? ?? ?? 48 03 CA FF E1 8B 4D 48 F6 C1 01 ?? ?? ?? ?? ?? ?? 48 8B 45 60 48 85 C0 ?? ?? ?? ?? ?? ?? 80 78 68 01 ?? ?? ?? ?? ?? ?? 0F BA E1 0F ?? ?? ?? ?? ?? ?? E8 ?? ?? ?? ?? 4C 8B A8 88 08 00 00 49 8B B5 38 02 00 00 48 89 74 24 40 48 8B CE 48 85 F6 74 11 B8 01 00 00 00 F0 0F C1 46 08 49 8B 8D 38 02 00 00 48 83 C1 10 E8 ?? ?? ?? ?? 48 8B D8 48 89 44 24 48 4C 89 6C 24 28 4C 8B CD 4C 8D 44 24 28 48 8D 94 24 B0 00 00 00 E8 ?? ?? ?? ?? 90 83 03 FF 75 ?? F0 44 0F C1 A6 1C 02 00 00 48 85 F6 74 ?? F0 44 0F C1 76 08 41 8D 46 FF 85 C0 75 ?? 48 8B 06 BA 01 00 00 00 48 8B CE FF 10 48 8B 8C 24 B0 00 00 00 48 85 C9 74 ?? 8B 41 28 0F BA E0 0B 72 ?? A8 20 75 ?? 0F B6 81 0A 01 00 00 90 84 C0 41 0F 95 C7 48 8B 8C 24 B0 00 00 00 48 C7 84 24 B0 00 00 00 00 00 00 00 48 85 C9 74 ?? E8 ?? ?? ?? ?? 45 84 FF 74 ?? 48 8D 4F 18 C5 FA 10 0D 38 ?? ?? ?? E8 ?? ?? ?? ?? 90
define(omniShipVitalsKeyHook,"Starfield.exe"+22F100E)

assert(omniShipVitalsKeyHook,48 8B 40 08 48 85 C0)
alloc(getShipVitalsKey,$1000,omniShipVitalsKeyHook)
alloc(playerShipActorValuesKey,8)

registersymbol(playerShipActorValuesKey)
registersymbol(omniShipVitalsKeyHook)

getShipVitalsKey:
    pushf
    push rbx
    push rcx
    mov rbx,[rax]
    mov rcx,extraActorValuesStorageType
    cmp rbx,[rcx]
    jne getShipVitalsKeyExit
    mov rbx,[rax+8]
    mov rcx,[rbx]
    mov rbx,extraPromotedRefType
    cmp rcx,[rbx]
    je getShipVitalsKeyExit
    push rax
    add rax,18
    mov [playerShipActorValuesKey],rax
    pop rax  
getShipVitalsKeyExit:
    pop rcx
    pop rbx
getShipVitalsKeyOriginalCode:
    popf
    mov rax,[rax+08]
    test rax,rax
    jmp getShipVitalsKeyReturn

omniShipVitalsKeyHook:
    jmp getShipVitalsKey
    nop 2
getShipVitalsKeyReturn:


// Gets updates to the player ship's vitals.
// rax: Matches against playerShipActorValuesKey if the vitals belong the player's ship.
// rbx: Identifying key of the vital type.
// [rax+10]: Number of ActorValueInfo entries.
// [rax+18]: The ActorValueInfo entries of size 0x18.
// xmm7: The maximum value for the vital being updated. Ignore if less than or equal to 1 and if not equal to xmm6.
// UNIQUE AOB: 48 83 C4 20 41 5F 41 5E 41 5C 5F 5E C3 CC 48 89 54 24 10 53 48 83 EC 30 48 8B DA
define(omniShipVitalsChangeHook,"Starfield.exe"+1A0A206)

assert(omniShipVitalsChangeHook,48 83 C4 20 41 5F)
alloc(getShipVitalsChange,$1000,omniShipVitalsChangeHook)
alloc(playerShipShieldOffset,8)
alloc(playerShipShield,8)
alloc(playerShipHullOffset,8)
alloc(playerShipHull,8)
alloc(playerShipMaxHull,8)
alloc(playerShipMaxShield,8)

registersymbol(playerShipMaxShield)
registersymbol(playerShipMaxHull)
registersymbol(playerShipHull)
registersymbol(playerShipHullOffset)
registersymbol(playerShipShield)
registersymbol(playerShipShieldOffset)
registersymbol(omniShipVitalsChangeHook)

getShipVitalsChange:
    pushf
    sub rsp,10
    movdqu [rsp],xmm0
    push rcx
    push rdx
    // Will point to the symbol referencing the ActorValueInfo address containing the vital's offset.
    push rsi
    // Will point to the symbol referencing the maximum value for the vital type.
    push rdi
    // Will point to the symbol referencing a calculated display value for the vital type.
    push r8
    // Will contain the maximum ActorValueInfo address entry to check.
    push r9
    // Check if these vitals belongs to the player's ship (as opposed to an NPC's ship).
    mov rcx,playerShipActorValuesKey
    cmp [rcx],rax
    jne getShipVitalsChangeExit
    // We ignore all iterations where xmm7 doesn't value greater than 1.
    mov ecx,0x3F800000
    movd xmm0,ecx
    ucomiss xmm7,xmm0
    jbe getShipVitalsChangeExit
    // We further ignore all iterations where xmm7 doesn't hold the same value as xmm6 
    // (will result in bad data if the vital is at 100% and the ship is moving, for example).
    ucomiss xmm7,xmm6
    jne getShipVitalsChangeExit    
    // Check if vital type is shield offset, otherwise check for hull offset.
    mov rcx,actorValueKeyShield
    cmp rbx,[rcx]
    jne checkForShipHull
    mov rsi,playerShipShieldOffset
    mov rdi,playerShipMaxShield
    mov r8,playerShipShield
    jmp searchForShipOffset
checkForShipHull:
    mov rcx,actorValueKeys
    cmp rbx,[rcx+108]
    jne getShipVitalsChangeExit    
    mov rsi,playerShipHullOffset
    mov rdi,playerShipMaxHull
    mov r8,playerShipHull
searchForShipOffset:
    // Find the maximum entry address before we abort our loop.
    mov ecx,[rax+10]
    imul ecx,18
    mov r9,[rax+18]
    add r9,ecx
    mov rcx,[rax+18]
nextShipActorValue:
    cmp rcx,r9
    jg shipVitalNotFound
    cmp [rcx],rbx
    je readShipVital
    add rcx,18
    jmp nextShipActorValue
readShipVital:
    mov [rsi],rcx
    movss [rdi],xmm7
    movss xmm0,[rcx+10]
    addss xmm0,xmm7
    movss [r8],xmm0
    jmp getShipVitalsChangeExit
shipVitalNotFound:
    // If the ship's vital type is at 100%, there will be no ActorValueInfo entry for it.
    // So, while we cannot point our offset symbol towards an ActorValueInfo address, we can
    // still produce an accurate calculated display value.
    movss [rdi],xmm7
    movss [r8],xmm7
getShipVitalsChangeExit:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    movdqu xmm0,[rsp]
    add rsp,10
getShipVitalsChangeOriginalCode:
    popf
    add rsp,20
    pop r15
    jmp getShipVitalsChangeReturn

omniShipVitalsChangeHook:
    jmp getShipVitalsChange
    nop 
getShipVitalsChangeReturn:


// Gets updates to the player's vitals (health, oxygen, etc.).
// [rax+rdx*4]: Address of vitals offset being updated.
// xmm1: New vitals offset.
// Unlike the player hook, which runs all the time, this only runs when active changes are occurring to the player's vitals.
// Despite this, when it does run, it executes far more frequently than the player hook. 
// Because of this, our display values for the vitals, which we export as a statistic, also need to be updated here so that all 
// changes are reported. 
// UNIQUE AOB: C5 FA 11 0C 90 * * * * EB
define(omniPlayerVitalsChangeHook,"Starfield.exe"+24CE02D)

assert(omniPlayerVitalsChangeHook,C5 FA 11 0C 90)
alloc(getPlayerVitalsChange,$1000,omniPlayerVitalsChangeHook)
alloc(deathCounter,8)

registersymbol(deathCounter)
registersymbol(omniPlayerVitalsChangeHook)

getPlayerVitalsChange:
    pushf
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm2
    push rbx
    push rcx
    push rsi
    // Check if updated vital stat is oxygen.
    // Unknown at this time if this procedure updates vitals in addition to oxygen, checking if it is the player's oxygen being changed to be sure.
    mov rcx,player
    mov rbx,[rcx]
    lea rcx,[rbx+3A4]
    lea rsi,[rax+rdx*4]
    cmp rcx,rsi
    je updatePlayerOxygen
    // Check if update vital stat is health.
    lea rcx,[rbx+398]
    cmp rcx,rsi
    je updatePlayerHealth    
    jmp getPlayerVitalsChangeExit
updatePlayerOxygen:
    mov rbx,playerMaxOxygen
    movss xmm0,[rbx]
    addss xmm0,xmm1
    mov rbx,playerOxygen
    movss [rbx],xmm0    
    jmp getPlayerVitalsChangeExit
updatePlayerHealth:
    mov rbx,playerMaxHealth
    movss xmm0, [rbx]
    addss xmm0,xmm1
    mov rbx,playerHealth
    // Back up to check if we're already in the negative (avoid duplicate death counts).
    movss xmm2,[rbx]
    movss [rbx],xmm0
    xorps xmm0,xmm0
    ucomiss xmm2,xmm0
    jbe getPlayerVitalsChangeExit
    // The player wasn't previously dead. Check if they are now.
    movss xmm0,[rbx]
    xorps xmm2,xmm2
    ucomiss xmm0,xmm2
    ja getPlayerVitalsChangeExit
    inc [deathCounter]
getPlayerVitalsChangeExit:
    pop rsi
    pop rcx
    pop rbx
    movdqu xmm2,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerVitalsChangeOriginalCode:
    popf
    vmovss [rax+rdx*4],xmm1
    jmp getPlayerVitalsChangeReturn

omniPlayerVitalsChangeHook:
    jmp getPlayerVitalsChange
getPlayerVitalsChangeReturn:


deathCounter:
    dd 0


// Gets the player's location information.
// This only polls the player's location, no filtering needed.
// rax: Player location structure (+0x50).
// The structure address is off by 0x50 (x-coordinate is normally at playerLocation+0x80), so adjustment is needed.
// UNIQUE AOB: 0F 58 78 30 0F B7 C7
define(omniPlayerLocationHook,"Starfield.exe"+C533A6)

assert(omniPlayerLocationHook,0F 58 78 30 0F B7 C7)
alloc(getPlayerLocation,$1000,omniPlayerLocationHook)
alloc(playerLocation,8)

registersymbol(playerLocation)
registersymbol(omniPlayerLocationHook)

getPlayerLocation:
    pushf
    push rax
    sub rax,0x50
    mov [playerLocation],rax
    pop rax
getPlayerLocationOriginalCode:
    popf
    addps xmm7,[rax+30]
    movzx eax,di
    jmp getPlayerLocationReturn

omniPlayerLocationHook:
    jmp getPlayerLocation
    nop 2
getPlayerLocationReturn:


// Gets the player ship's location information.
// rcx: The player ship's bhkCharProxyController. The hknpBSCharacterProxy (which contains the coords) can be found at [rcx+4D0].
// UNIQUE AOB: 2A 48 8D 48 20 48 8B 01 48 8D 54 24 30
define(omniPlayerShipLocationHook,"Starfield.exe"+1F8A35B)

assert(omniPlayerShipLocationHook,48 8B 01 48 8D 54 24 30)
alloc(getPlayerShipLocation,$1000,omniPlayerShipLocationHook)
alloc(playerShipLocation,8)

registersymbol(playerShipLocation)
registersymbol(omniPlayerShipLocationHook)

getPlayerShipLocation:
    pushf
    push rax
    mov rax,[rcx+4D0]
    mov [playerShipLocation],rax
    pop rax
getPlayerShipLocationOriginalCode:
    popf
    mov rax,[rcx]
    lea rdx,[rsp+30]
    jmp getPlayerShipLocationReturn

omniPlayerShipLocationHook:
    jmp getPlayerShipLocation
    nop 3
getPlayerShipLocationReturn:


// Detects when the player is piloting their ship.
// UNIQUE AOB: C5 F8 11 83 80 00 00 00 E8
define(omniPlayerInShipHook,"Starfield.exe"+2D7A6AD)

assert(omniPlayerInShipHook,C5 F8 11 83 80 00 00 00)
alloc(isPlayerInShip,$1000,omniPlayerInShipHook)
alloc(playerInShip,8)
alloc(hidePlayerHealth,8)
alloc(hidePlayerStamina,8)
alloc(hidePlayerCoordinates,8)

registersymbol(hidePlayerCoordinates)
registersymbol(hidePlayerStamina)
registersymbol(hidePlayerHealth)
registersymbol(playerInShip)
registersymbol(omniPlayerInShipHook)

isPlayerInShip:
    mov [playerInShip],1
    mov [hidePlayerHealth],1
    mov [hidePlayerStamina],1
    mov [hidePlayerCoordinates],1
isPlayerInShipOriginalCode:
    vmovups [rbx+00000080],xmm0
    jmp isPlayerInShipReturn

omniPlayerInShipHook:
    jmp isPlayerInShip
    nop 3
isPlayerInShipReturn:


// Detects when the player is no longer piloting their ship.
// rax: x-coordinate member of character proxy being polled (adjust by -0x80 to normalize)
// UNIQUE AOB: C5 F8 10 00 C4 C1 78 11 06 48 8B 03
define(omniPlayerNotInShipHook,"Starfield.exe"+2D78D27)

assert(omniPlayerNotInShipHook,C5 F8 10 00 C4 C1 78 11 06)
alloc(isPlayerNotInShip,$1000,omniPlayerNotInShipHook)

registersymbol(omniPlayerNotInShipHook)

isPlayerNotInShip:
    pushf
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je isPlayerNotInShipOriginalCode
    push rax
    push rbx
    sub rax,80
    mov rbx,playerLocation
    cmp rax,[rbx]
    jne isPlayerNotInShipExit
    // We are not piloting da ship. No longer sitting on da cockpit seat.
    mov rax,playerInShip
    mov [rax],0
    mov rax,hidePlayerHealth
    mov [rax],0
    mov rax,hidePlayerStamina
    mov [rax],0
    mov rax,hidePlayerCoordinates
    mov [rax],0
isPlayerNotInShipExit:
    pop rbx
    pop rax
isPlayerNotInShipOriginalCode:
    popf
    vmovups xmm0,[rax]
    vmovups [r14],xmm0
    jmp isPlayerNotInShipReturn

omniPlayerNotInShipHook:
    jmp isPlayerNotInShip
    nop 4
isPlayerNotInShipReturn:


// Gets the magazine of the currently equipped weapon.
// rbx: Ammunition module for the equipped weapon (EquippedWeapon::AmmunitionModule).
// [rbx+10]: The ammunition type -- we filter out structures that lack an ammunition type, as this corresponds to an (atm unknown) 
//           ammunition type (unrelated to our equipped weapon) which is constantly being polled.
// [rbx+18]: Remaining number of bullets in the magazine.
// r12: PlayerCharacter structure for entity that magazine belongs to.
// UNIQUE AOB: 8B 7B 18 C5 F0 57 C9
define(omniPlayerMagazineHook,"Starfield.exe"+1F2BB3A)

assert(omniPlayerMagazineHook,8B 7B 18 C5 F0 57 C9)
alloc(getPlayerMagazine,$1000,omniPlayerMagazineHook)
alloc(playerMagazine,8)

registersymbol(playerMagazine)
registersymbol(omniPlayerMagazineHook)

getPlayerMagazine:
    pushf
    push rax
    push rcx
    mov rax,player
    mov rcx,[player]
    mov eax,[rbx+10]
    cmp eax,0
    je getPlayerMagazineExit
    cmp rcx,r12
    jne getPlayerMagazineExit
    mov [playerMagazine],rbx
getPlayerMagazineExit:
    pop rcx
    pop rax
getPlayerMagazineOriginalCode:
    popf
    mov edi,[rbx+18]
    vxorps xmm1,xmm1,xmm1
    jmp getPlayerMagazineReturn

omniPlayerMagazineHook:
    jmp getPlayerMagazine
    nop 2
getPlayerMagazineReturn:


// Gets the total ammo of a weapon when switching to it, firing it after a reload, alt-tabbing back into the game, and loading a save file, but NOT when reloading the gun.
// r14: TESAmmo type
// r9: Ammo amount
// UNIQUE AOB: 41 8B C1 C3 CC CC CC CC CC 48
define(omniPlayerAmmoHook,"Starfield.exe"+19CBFF7)

assert(omniPlayerAmmoHook,41 8B C1 C3 CC)
alloc(getPlayerAmmo,$1000,omniPlayerAmmoHook)
alloc(playerAmmo,8)

registersymbol(playerAmmo)
registersymbol(omniPlayerAmmoHook)

getPlayerAmmo:
    pushf
    push rax
    mov rax,playerMagazine
    cmp [rax],0
    pop rax
    je getPlayerAmmoOriginalCode
    push rbx
    push rdx  
    // Data other than our current weapon's ammo is polled here. Filter them out by matching the ammo type with what's in [playerMagazine+10].
    mov rdx,playerMagazine
    mov rbx,[rdx]
    cmp r14,[rbx+10]
    jne getPlayerAmmoExit
    mov [playerAmmo],r9
    // Subtract what's currently in the clip to get an accurate "remaining" count.
    mov rdx,[rbx+18]
    sub [playerAmmo],rdx
getPlayerAmmoExit:
    pop rdx
    pop rbx
getPlayerAmmoOriginalCode:
    popf
    mov eax,r9d
    ret 
    int 3 
    jmp getPlayerAmmoReturn

omniPlayerAmmoHook:
    jmp getPlayerAmmo
getPlayerAmmoReturn:


// Fires when the ammo count in the magazine changes.
// UNIQUE AOB: 89 71 18 48 8D 4C 24 20
// rcx: Container undergoing change.
// esi: New ammo count.
define(omniPlayerMagazineChangeHook,"Starfield.exe"+1A22E46)

assert(omniPlayerMagazineChangeHook,89 71 18 48 8D 4C 24 20)
alloc(getPlayerMagazineChange,$1000,omniPlayerMagazineChangeHook)

registersymbol(omniPlayerMagazineChangeHook)

getPlayerMagazineChange:
    pushf
    push rax
    push rbx
    // Check if the container being updated is the player's magazine.
    mov rax,playerMagazine
    mov rbx,[rax]
    cmp rbx,rcx
    jne getPlayerMagazineChangeExit
    // Check if the change is from a reload (new ammo count will be greater than current ammo count).
    cmp esi,[rcx+18]
    jle getPlayerMagazineChangeExit
    // Subtract the number of additional bullets being loaded into the magazine from our total ammo count.
    mov rax,esi
    sub rax,[rcx+18]
    mov rbx,playerAmmo
    sub [rbx],rax
getPlayerMagazineChangeExit:
    pop rbx
    pop rax
getPlayerMagazineChangeOriginalCode:
    popf
    mov [rcx+18],esi
    lea rcx,[rsp+20]
    jmp getPlayerMagazineChangeReturn

omniPlayerMagazineChangeHook:
    jmp getPlayerMagazineChange
    nop 3
getPlayerMagazineChangeReturn:


// Gets the player's equip load.
// rcx: BGSInventoryList
// [rcx+3C]: Equip load.
// rbx: Entity that owns the inventory (PlayerCharacter if it is the players).
// UNIQUE AOB: C5 F8 2E 41 3C 40
define(omniPlayerEquipLoad,"Starfield.exe"+1A0F588)

assert(omniPlayerEquipLoad,C5 F8 2E 41 3C)
alloc(getPlayerEquipLoad,$1000,omniPlayerEquipLoad)
alloc(playerEquipLoad,8)

registersymbol(playerEquipLoad)
registersymbol(omniPlayerEquipLoad)

getPlayerEquipLoad:
    pushf
    push rax
    mov rax,player
    cmp [rax],rbx
    pop rax
    jne getPlayerEquipLoadOriginalCode
    push rax
    mov rax,[rcx+3C]
    mov [playerEquipLoad],rax
    pop rax
getPlayerEquipLoadOriginalCode:
    popf
    vucomiss xmm0,[rcx+3C]
    jmp getPlayerEquipLoadReturn

omniPlayerEquipLoad:
    jmp getPlayerEquipLoad

getPlayerEquipLoadReturn:


// Gets the player's max equip load.
// rcx - rax: 0x20 when UI value is max equip load.
// rsi: 0x5 when UI value is max equip load.
// [rcx+18]: UI value.
// UNIQUE AOB: 48 8B FA 48 8B D9 ?? ?? ?? ?? ?? C5 FA 10 53 18 C5 FA 10 07
define(omniPlayerMaxEquipLoad,"Starfield.exe"+13D90BA)

assert(omniPlayerMaxEquipLoad,48 8B FA 48 8B D9)
alloc(getPlayerMaxEquipLoad,$1000,omniPlayerMaxEquipLoad)
alloc(playerTotalMaxEquipLoad,8)

registersymbol(playerTotalMaxEquipLoad)
registersymbol(omniPlayerMaxEquipLoad)

getPlayerMaxEquipLoad:
    pushf
    push rcx
    sub rcx,rax
    cmp ecx,0x20
    pop rcx
    jne getPlayerMaxEquipLoadOriginalCode
    cmp rsi,0x5
    jne getPlayerMaxEquipLoadOriginalCode
    push rbx
    mov rbx,[rcx+18]
    mov [playerTotalMaxEquipLoad],rbx
    pop rbx
getPlayerMaxEquipLoadOriginalCode:
    popf
    mov rdi,rdx
    mov rbx,rcx
    jmp getPlayerMaxEquipLoadReturn

omniPlayerMaxEquipLoad:
    jmp getPlayerMaxEquipLoad
    nop 
getPlayerMaxEquipLoadReturn:


// Initiates the Apocalypse system.
// This code runs whenever any player/npc vital metric is being updated (health, oxygen, others unknown).
// [rax+8]: Offset value being updated.
// rsi: Base of either PlayerCharacter or Actor struct receiving change.
// xmm7: Signed damage offset being done.
// xmm0: Working health offset.
// xmm1: Maximum health value.
// (rax - rsi) will equal 0x390 when it is the health being updated.
// Filter out RAX==0x1 (junk).
// rbx: Damage source (Either PlayerCharacter or Actor)
// Filter out RBX==0x0 (environmental sourced).
// UNIQUE AOB: C5 FA 58 D7 C5 FA 11 55 48
define(omnifyApocalypseHook,"Starfield.exe"+24D276D)

assert(omnifyApocalypseHook,C5 FA 58 D7 C5 FA 11 55 48)
alloc(initiateApocalypse,$1000,omnifyApocalypseHook)

registersymbol(omnifyApocalypseHook)

initiateApocalypse:
    pushf
    // Check if junk.
    cmp rax,1
    je initiateApocalypseOriginalCode   
    // Filter out environmental damage.
    cmp rbx,0
    je initiateApocalypseOriginalCode
    // Check if the necessary pointers have been found.
    push rax
    mov rax,player
    cmp [rax],0    
    pop rax    
    je initiateApocalypseOriginalCode
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je initiateApocalypseOriginalCode
    // Check if health is being updated.
    push rax 
    sub rax,rsi
    cmp rax,0x390
    pop rax
    jne initiateApocalypseOriginalCode    
    sub rsp,10
    movdqu [rsp],xmm2
    sub rsp,10
    movdqu [rsp],xmm3
    sub rsp,10
    movdqu [rsp],xmm4
    push rax
    push rbx
    push rcx
    // Back up the new and working health offsets in case we need to restore them due to an Apocalypse abortion.
    movss xmm3,xmm0
    movss xmm4,xmm7
    // Make the damage offset unsigned and then load it as the first common parameter.
    mov rcx,0x80000000
    movd xmm2,rcx
    xorps xmm7,xmm2
    sub rsp,8
    movd [rsp],xmm7
    // Calculate current health and then load it as the second common parameter.
    addss xmm0,xmm1    
    sub rsp,8
    movd [rsp],xmm0
    // Check if player's health is being updated, or an NPC's.
    mov rax,player
    mov rcx,[rax]    
    cmp rcx,rsi
    je initiatePlayerApocalypse
    jmp initiateEnemyApocalypse
initiatePlayerApocalypse:
    // Load the maximum health as the next parameter.
    sub rsp,8
    movd [rsp],xmm1
    // Finally, load the player's location structure, aligned at the x-coordinate.
    mov rax,playerLocation
    mov rcx,[rax]    
    lea rax,[rcx+80]
    push rax
    call executePlayerApocalypse
    jmp initiateApocalypseUpdateDamage
initiateEnemyApocalypse:
    // An enemy is being damaged. Check if the player is the source of the damage.
    cmp rcx,rbx
    jne abortApocalypse
    call executeEnemyApocalypse 
initiateApocalypseUpdateDamage:
    // Convert updated damage offset back to signed format.
    movd xmm7,eax
    mov rcx,0x80000000
    movd xmm2,rcx
    xorps xmm7,xmm2
    // Convert updated working health value into an offset (new health - maximum health).
    movd xmm0,ebx
    movss xmm2,xmm1
    subss xmm0,xmm2
    jmp initiateApocalypseCleanup
abortApocalypse:
    // Adjust the stack to account for the common parameters that weren't used.
    add rsp,10
    // Restore the original health offset values.
    movss xmm0,xmm3
    movss xmm7,xmm4
initiateApocalypseCleanup:
    pop rcx
    pop rbx
    pop rax
    movdqu xmm4,[rsp]
    add rsp,10
    movdqu xmm3,[rsp]
    add rsp,10
    movdqu xmm2,[rsp]
    add rsp,10
initiateApocalypseOriginalCode:
    popf
    vaddss xmm2,xmm0,xmm7
    vmovss [rbp+48],xmm2
    jmp initiateApocalypseReturn

omnifyApocalypseHook:
    jmp initiateApocalypse
    nop 4
initiateApocalypseReturn:


yIsVertical:
    dd 0

// Launch our ass.
verticalTeleportitisDisplacementX:
    dd (float)100.0

// Since teleportitis is always hilariously fatal...10 min cooldown.
teleportitisCooldownMinutes:
    dd 10

// Falling underneath ground doesn't kill you (TYPICAL BETHESDA).
negativeVerticalDisplacementEnabled:
    dd 0

// Damage sustained by the player during combat is typically in the form of numerous tiny mosquito bites
// (i.e., getting sprayed by automatic gunfire). A cooldown is implemented to avoid an otherwise excessively
// noisy Apocalypse experience.
apocalypseCooldownMilliseconds:
    dd #500

// On that note, given the prevalence of tiny damage being dealt to the player, we increase our damage modifiers
// accordingly.
extraDamageX:
    dd (float)4.0

murderDamageX:
    dd (float)6969.0


// Initiates the Predator system.
// This is the movement application subroutine for NPCs (not the player).
// xmm1: x- and y-offsets (double precision)
// xmm0: z-offset
// [rsi+10]: current x- and y-coordinates for NPC (double precision, again)
// [rsi+20]: current z-offset for NPC
// UNIQUE AOB: 66 0F 58 E1 66 0F 58 D0
define(omnifyPredatorHook,"Starfield.exe"+1224F44)

assert(omnifyPredatorHook,66 0F 58 E1 66 0F 58 D0)
alloc(initiatePredator,$1000,omnifyPredatorHook)
alloc(identityValue,8)
registersymbol(omnifyPredatorHook)

initiatePredator:
    pushf
    // Ensure the player's location struct has been found.
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je initiatePredatorOriginalCode
    // Backup calculation and output registers.
    sub rsp,10
    movdqu [rsp],xmm2
    sub rsp,10
    movdqu [rsp],xmm3
    push rax
    push rbx
    push rcx
    // Push the player's current coordinates.
    mov rax,playerLocation
    mov rbx,[rax]
    push [rbx+80]
    push [rbx+88]
    // Push the enemy's current coordinates.
    cvtpd2ps xmm2,[rsi+10]
    cvtpd2ps xmm3,[rsi+20]
    sub rsp,8
    movq [rsp],xmm2
    sub rsp,8
    movq [rsp],xmm3
    // Push an identity matrix for the scaling parameters.
    movss xmm2,[identityValue]
    shufps xmm2,xmm2,0
    sub rsp,10
    movdqu [rsp],xmm2
    // Push the enemy's movement offsets.
    cvtpd2ps xmm2,xmm1
    cvtpd2ps xmm3,xmm0
    sub rsp,8
    movq [rsp],xmm2
    sub rsp,8
    movq [rsp],xmm3
    call executePredator
initiatePredatorUpdateOffsets:
    // Propagate the updated x-, y-, and z-movement offsets to xmm1.
    sub rsp,10
    mov [rsp],eax
    mov [rsp+4],ebx
    mov [rsp+8],ecx
    cvtps2pd xmm1,[rsp]
    cvtps2pd xmm0,[rsp+8]
    add rsp,10
initiatePredatorCleanup:
    pop rcx
    pop rbx
    pop rax
    movdqu xmm3,[rsp]
    add rsp,10
    movdqu xmm2,[rsp]
    add rsp,10
initiatePredatorOriginalCode:
    popf
    addpd xmm4,xmm1
    addpd xmm2,xmm0
    jmp initiatePredatorReturn

omnifyPredatorHook:
    jmp initiatePredator
    nop 3
initiatePredatorReturn:

identityValue:
    dd (float)1.0


// Manipulates the player's speed.
// xmm0: The movement offsets.
// UNIQUE AOB: 0F 58 83 80 00 00 00
define(omnifyPlayerSpeedHook,"Starfield.exe"+C094AA)

assert(omnifyPlayerSpeedHook,0F 58 83 80 00 00 00)
alloc(applyPlayerSpeed,$1000,omnifyPlayerSpeedHook)
alloc(playerSpeedX,8)

registersymbol(playerSpeedX)
registersymbol(omnifyPlayerSpeedHook)

applyPlayerSpeed:
    pushf
    sub rsp,10
    movdqu [rsp],xmm1
    sub rsp,10
    movdqu [rsp],xmm2
    // Jerky collision with terrain is somewhat remedied by applying boost to
    // vertical axis as well.
    movss xmm1,[playerSpeedX]
    shufps xmm1,xmm1,0
    mulps xmm0,xmm1
    movdqu xmm2,[rsp]
    add rsp,10
    movdqu xmm1,[rsp]
    add rsp,10
applyPlayerSpeedOriginalCode:
    popf
    addps xmm0,[rbx+00000080]
    jmp applyPlayerSpeedReturn

omnifyPlayerSpeedHook:
    jmp applyPlayerSpeed
    nop 2
applyPlayerSpeedReturn:


playerSpeedX:
    dd (float)1.0


// Initiates (and applies) the Abomnification system.
// UNIQUE AOB (more or less): C5 F2 59 63 7C C5 FA 10 55 E4 C5 EA 58 40 28
// rsi: PlayerCharacter/Actor struct associated with the scale.
// [rbx+7C]: Uniform scaling parameter.
define(omnifyAbomnificationHook,"Starfield.exe"+1A0A93C)

assert(omnifyAbomnificationHook,C5 F2 59 63 7C)
alloc(initiateAbomnification,$1000,omnifyAbomnificationHook)
alloc(averageScaleDivisor,8)
alloc(abomnifyPlayer,8)

registersymbol(abomnifyPlayer)
registersymbol(averageScaleDivisor)
registersymbol(omnifyAbomnificationHook)

initiateAbomnification:
    pushf
    push rax
    mov rax,player
    cmp [rax],0
    pop rax
    je initiateAbomnificationOriginalCode
    push rax
    mov rax,player
    cmp [rax],rsi
    pop rax
    je initiateAbomnificationOriginalCode
    // Back up Abomnification output registers as well as some SSE registers for finding the average
    // dimensional scale.
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm1
    push rax
    push rbx
    push rcx
    // Back up rbx so we can update the scaling parameter with our output.
    push rdx
    mov rdx,rbx
    // Push the BSFadeNode struct address, which is one-per-entity and holds the scaling parameter, as 
    // the identifying address.
    push rdx
    call executeAbomnification
    // Forced static unnatural is used for this game. Generated dimensional scales will all be uniform, so we'll just arbitrarily 
    // use the width.
    movd xmm0,rax   
    movss [rdx+7C],xmm0
    pop rdx
    pop rcx
    pop rbx
    pop rax
    movdqu xmm1,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
initiateAbomnificationOriginalCode:
    popf
    vmulss xmm4,xmm1,[rbx+7C]
    jmp initiateAbomnificationReturn

omnifyAbomnificationHook:
    jmp initiateAbomnification
initiateAbomnificationReturn:

abomnifyPercentage:
    dd #25

forceStaticUnnatural:
    dd 1

abomnifyPlayer:
    dd 0

averageScaleDivisor:
    dd (float)3.0


[DISABLE]


// Cleanup of omnifyAbomnificationHook
omnifyAbomnificationHook:
    db C5 F2 59 63 7C

unregistersymbol(omnifyAbomnificationHook)
unregistersymbol(averageScaleDivisor)
unregistersymbol(abomnifyPlayer)

dealloc(abomnifyPlayer)
dealloc(averageScaleDivisor)
dealloc(initiateAbomnification)


// Cleanup of omnifyPlayerSpeedHook
omnifyPlayerSpeedHook:
    db 0F 58 83 80 00 00 00

unregistersymbol(omnifyPlayerSpeedHook)
unregistersymbol(playerSpeedX)

dealloc(playerSpeedX)
dealloc(applyPlayerSpeed)


// Cleanup of omnifyPredatorHook
omnifyPredatorHook:
    db 66 0F 58 E1 66 0F 58 D0

unregistersymbol(omnifyPredatorHook)

dealloc(identityValue)
dealloc(initiatePredator)


// Cleanup of omnifyApocalypseHook
omnifyApocalypseHook:
    db C5 FA 58 D7 C5 FA 11 55 48

unregistersymbol(omnifyApocalypseHook)

dealloc(initiateApocalypse)


// Cleanup of omniPlayerMaxEquipLoad
omniPlayerMaxEquipLoad:
    db 48 8B FA 48 8B D9

unregistersymbol(omniPlayerMaxEquipLoad)
unregistersymbol(playerTotalMaxEquipLoad)

dealloc(playerTotalMaxEquipLoad)
dealloc(getPlayerMaxEquipLoad)


// Cleanup of omniPlayerEquipLoad
omniPlayerEquipLoad:
    db C5 F8 2E 41 3C

unregistersymbol(omniPlayerEquipLoad)
unregistersymbol(playerEquipLoad)

dealloc(playerEquipLoad)
dealloc(getPlayerEquipLoad)


// Cleanup of omniPlayerMagazineChangeHook
omniPlayerMagazineChangeHook:
    db 89 71 18 48 8D 4C 24 20

unregistersymbol(omniPlayerMagazineChangeHook)

dealloc(getPlayerMagazineChange)


// Cleanup of omniPlayerAmmoHook
omniPlayerAmmoHook:
    db 41 8B C1 C3 CC

unregistersymbol(omniPlayerAmmoHook)
unregistersymbol(playerAmmo)

dealloc(playerAmmo)
dealloc(getPlayerAmmo)


// Cleanup of omniPlayerMagazineHook
omniPlayerMagazineHook:
    db 8B 7B 18 C5 F0 57 C9

unregistersymbol(omniPlayerMagazineHook)
unregistersymbol(playerMagazine)

dealloc(playerMagazine)
dealloc(getPlayerMagazine)


// Cleanup of omniPlayerLocationHook
omniPlayerLocationHook:
    db 0F 58 78 30 0F B7 C7

unregistersymbol(omniPlayerLocationHook)
unregistersymbol(playerLocation)

dealloc(playerLocation)
dealloc(getPlayerLocation)


// Cleanup of omniPlayerNotInShipHook
omniPlayerNotInShipHook:
    db C5 F8 10 00 C4 C1 78 11 06

unregistersymbol(omniPlayerNotInShipHook)

dealloc(isPlayerNotInShip)


// Cleanup of omniPlayerInShipHook
omniPlayerInShipHook:
    db C5 F8 11 83 80 00 00 00

unregistersymbol(omniPlayerInShipHook)
unregistersymbol(playerInShip)
unregistersymbol(hidePlayerHealth)
unregistersymbol(hidePlayerStamina)
unregistersymbol(hidePlayerCoordinates)

dealloc(hidePlayerCoordinates)
dealloc(hidePlayerStamina)
dealloc(hidePlayerHealth)
dealloc(playerInShip)
dealloc(isPlayerInShip)


// Cleanup of omniPlayerShipLocationHook
omniPlayerShipLocationHook:
    db 48 8B 01 48 8D 54 24 30

unregistersymbol(omniPlayerShipLocationHook)
unregistersymbol(playerShipLocation)

dealloc(playerShipLocation)
dealloc(getPlayerShipLocation)


// Cleanup of omniPlayerVitalsChangeHook
omniPlayerVitalsChangeHook:
    db C5 FA 11 0C 90

unregistersymbol(omniPlayerVitalsChangeHook)
unregistersymbol(deathCounter)

dealloc(deathCounter)
dealloc(getPlayerVitalsChange)


// Cleanup of omniShipVitalsChangeHook
omniShipVitalsChangeHook:
    db 48 83 C4 20 41 5F

unregistersymbol(omniShipVitalsChangeHook)
unregistersymbol(playerShipShieldOffset)
unregistersymbol(playerShipShield)
unregistersymbol(playerShipHullOffset)
unregistersymbol(playerShipHull)
unregistersymbol(playerShipMaxHull)
unregistersymbol(playerShipMaxShield)

dealloc(playerShipMaxShield)
dealloc(playerShipMaxHull)
dealloc(playerShipHull)
dealloc(playerShipHullOffset)
dealloc(playerShipShield)
dealloc(playerShipShieldOffset)
dealloc(getShipVitalsChange)


// Cleanup of omniExtraActorValueStorageTypeHook
omniExtraActorValueStorageTypeHook:
    db 48 89 5C 24 08

unregistersymbol(omniExtraActorValueStorageTypeHook)
unregistersymbol(extraActorValuesStorageType)

dealloc(extraActorValuesStorageType)
dealloc(getExtraActorValueStorageType)


// Cleanup of omniExtraPromotedRefTypeHook
omniExtraPromotedRefTypeHook:
    db 48 89 5C 24 08

unregistersymbol(omniExtraPromotedRefTypeHook)
unregistersymbol(extraPromotedRefType)

dealloc(extraPromotedRefType)
dealloc(getExtraPromotedRefType)


// Cleanup of omniShipVitalsKeyHook
omniShipVitalsKeyHook:
    db 48 8B 40 08 48 85 C0

unregistersymbol(omniShipVitalsKeyHook)
unregistersymbol(playerShipActorValuesKey)

dealloc(playerShipActorValuesKey)
dealloc(getShipVitalsKey)


// Cleanup of omniPlayerHook
omniPlayerHook:
    db 48 8B 01 48 8B FA

unregistersymbol(omniPlayerHook)    
unregistersymbol(player)
unregistersymbol(playerMaxHealth)
unregistersymbol(playerMaxOxygen)
unregistersymbol(playerHealth)
unregistersymbol(playerOxygen)
unregistersymbol(playerMaxEquipLoad)

dealloc(playerMaxEquipLoad)
dealloc(playerOxygen)
dealloc(playerHealth)
dealloc(playerMaxOxygen)
dealloc(playerMaxHealth)
dealloc(player)
dealloc(getPlayer)


// Cleanup of omniPlayerCharacterTypeHook
omniPlayerCharacterTypeHook:
    db 49 8B 06 49 8B CE

unregistersymbol(omniPlayerCharacterTypeHook)
unregistersymbol(playerCharacterType)

dealloc(playerCharacterType)
dealloc(getPlayerCharacterType)

// Cleanup of getActorValue
unregistersymbol(getActorValue)

dealloc(getActorValue)

// Cleanup of omniActorValueKeyShieldHook
unregistersymbol(actorValueKeyShield)

// Cleanup of omniActorValueKeysHook
unregistersymbol(actorValueKeys)