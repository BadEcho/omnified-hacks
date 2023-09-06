//----------------------------------------------------------------------
// Hooks for Omnified Starfield
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2023 Bad Echo LLC
//
// Bad Echo Technologies are licensed under a
//      GNU Affero General Public License v3.0.
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
// The effective value type is located at [[actorValueInfo+0xB0]+x0]
//
// Known ActorValueInfo Types:
//  Maximum Oxygen - 0x8
//  Maximum Health - 0x108
omniActorValueKeysHook+(DWORD)[omniActorValueKeysHook+3]+7:
actorValueKeys:


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
    push rcx    
    mov rax,[rsp+28]
    mov rbx,[rax+B0]
    mov rax,[rbx]
    mov rbx,[rsp+20]
    mov rcx,[rsp+18]
nextActorValue:
    // Check if we're past the last ActorValueInfo entry.
    cmp rbx,rcx
    jg getActorValueExit
    cmp rax,[rbx]    
    je readActorValue
    add rbx,10
    jmp nextActorValue
readActorValue:
    mov rax,[rbx+8]
getActorValueExit:
    pop rcx
    pop rbx
    ret 18


// Gets the player's root structure.
// Effective health is located at [player]+0x3B8 -- it is stored as an offset (seems to be either 0 or a negative value, which you add to the maximum health to get your health).
// Effective oxygen is located at [player]+0x3C4 -- also an offset.
// Maximum health is an ActorValueInfo property whose key value can be found at [[actorValueKeys+0x108]+0xB0]+x0]
// In order to find ActorValueInfo values, search in [player+0x2A0], for specific key at [entry+0x0] every 16 bytes. Value is at matched [entry+0x8].
// UNIQUE AOB: 48 8B 01 48 8B FA 33 DB FF 90 E0
define(omniPlayerHook,"Starfield.exe"+1A096CE)

assert(omniPlayerHook,48 8B 01 48 8B FA)
alloc(getPlayer,$1000,omniPlayerHook)
alloc(player,8)
alloc(playerHealth,8)
alloc(playerMaxHealth,8)
alloc(playerMaxOxygen,8)
alloc(playerOxygen,8)

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
    mov [player],rcx        
    // Calculate the max ActorValueInfo entry address to check based on the number of entries stored at [player+0x298].
    mov rax,[rcx+298]
    mov rdx,10
    mul rdx
    add rax,[rcx+2A0]
    mov rbx,rax    
    // Find the maximum health value.
    push [actorValueKeys+108]
    push [rcx+2A0]
    push rbx
    call getActorValue
    mov [playerMaxHealth],rax
    // Find the maximum oxygen value.
    push [actorValueKeys+8]
    push [rcx+2A0]
    push rbx
    call getActorValue
    mov [playerMaxOxygen],rax 
    // Calculate display values for current health and oxygen.
    movss xmm0,[rcx+3B8]
    addss xmm0,[playerMaxHealth]
    movss [playerHealth],xmm0
    movss xmm0,[rcx+3C4]
    addss xmm0,[playerMaxOxygen]
    movss [playerOxygen],xmm0
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


// Gets changes to the player's oxygen level.
// [rax+rdx*4]: Address of oxygen offset being updated.
// xmm1: New oxygen offset.
// Unlike the player hook, which runs all the time, this only runs when active changes are occurring to the player's oxygen.
// Despite this, when it does run, it executes far more frequently than the player hook. 
// Because of this, our display value for oxygen, which we export as a statistic, also needs to be updated here so that all 
// changes are reported. 
// UNIQUE AOB: C5 FA 11 0C 90 * * * * EB
define(omniPlayerOxygenChangeHook,"Starfield.exe"+24BCEDD)

assert(omniPlayerOxygenChangeHook,C5 FA 11 0C 90)
alloc(getPlayerOxygenChange,$1000,omniPlayerOxygenChangeHook)

registersymbol(omniPlayerOxygenChangeHook)

getPlayerOxygenChange:
    pushf
    sub rsp,10
    movdqu [rsp],xmm0
    push rbx
    push rcx
    // Unknown at this time if this procedure updates vitals in addition to oxygen, checking if it is the player's oxygen being changed to be sure.
    mov rcx,player
    mov rbx,[rcx]
    lea rcx,[rbx+3C4]
    lea rbx,[rax+rdx*4]
    cmp rcx,rbx
    jne getPlayerOxygenChangeExit
    mov rbx,playerMaxOxygen
    movss xmm0,[playerMaxOxygen]
    addss xmm0,xmm1
    mov rbx,playerOxygen
    movss [rbx],xmm0    
getPlayerOxygenChangeExit:
    pop rcx
    pop rbx
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerOxygenChangeOriginalCode:
    popf
    vmovss [rax+rdx*4],xmm1
    jmp getPlayerOxygenChangeReturn

omniPlayerOxygenChangeHook:
    jmp getPlayerOxygenChange
getPlayerOxygenChangeReturn:


// Gets the player's location information.
// This only polls the player's location, no filtering needed.
// rax: Player location structure (+0x50).
// The structure address is off by 0x50 (x-coordinate is normally at playerLocation+0x80), so adjustment is needed.
define(omniPlayerLocationHook,"Starfield.exe"+C52546)

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


// Gets the magazine of the currently equipped weapon.
// rbx: Ammunition module for the equipped weapon (EquippedWeapon::AmmunitionModule).
// [rbx+10]: The ammunition type -- we filter out structures that lack an ammunition type, as this corresponds to an (atm unknown) 
//           ammunition type (unrelated to our equipped weapon) which is constantly being polled.
// [rbx+18]: Remaining number of bullets in the magazine.
// UNIQUE AOB: 8B 7B 18 C5 F0 57 C9
define(omniPlayerMagazineHook,"Starfield.exe"+1F2649A)

assert(omniPlayerMagazineHook,8B 7B 18 C5 F0 57 C9)
alloc(getPlayerMagazine,$1000,omniPlayerMagazineHook)
alloc(playerMagazine,8)

registersymbol(playerMagazine)
registersymbol(omniPlayerMagazineHook)

getPlayerMagazine:
    pushf
    push rax
    mov eax,[rbx+10]
    cmp eax,0
    je getPlayerMagazineExit
    mov [playerMagazine],rbx
getPlayerMagazineExit:
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


[DISABLE]

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


// Cleanup of omniPlayerOxygenChangeHook
omniPlayerOxygenChangeHook:
    db C5 FA 11 0C 90

unregistersymbol(omniPlayerOxygenChangeHook)

dealloc(getPlayerOxygenChange)


// Cleanup of omniPlayerHook
omniPlayerHook:
    db 48 8B 01 48 8B FA

unregistersymbol(omniPlayerHook)    
unregistersymbol(player)
unregistersymbol(playerMaxHealth)
unregistersymbol(playerMaxOxygen)
unregistersymbol(playerHealth)
unregistersymbol(playerOxygen)

dealloc(playerOxygen)
dealloc(playerHealth)
dealloc(playerMaxOxygen)
dealloc(playerMaxHealth)
dealloc(player)
dealloc(getPlayer)


// Cleanup of getActorValue
unregistersymbol(getActorValue)

dealloc(getActorValue)


// Cleanup of omniActorValueKeysHook
unregistersymbol(actorValueKeys)