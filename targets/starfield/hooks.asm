//----------------------------------------------------------------------
// Hooks for Omnified Starfield
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2023 Bad Echo LLC
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
// r12: PlayerCharacter structure for entity that magazine belongs to.
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
define(omniPlayerAmmoHook,"Starfield.exe"+19C6247)

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
define(omniPlayerMagazineChangeHook,"Starfield.exe"+1A1C7C6)

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


// Initiates the Apocalypse system.
// This code runs whenever any player/npc vital metric is being updated (health, oxygen, others unknown).
// [rax+8]: Offset value being updated.
// rsi: Base of either PlayerCharacter or Actor struct receiving change.
// xmm7: Signed damage offset being done.
// xmm0: Working health offset.
// xmm1: Maximum health value.
// (rax - rsi) will equal 0x3B0 when it is the health being updated.
// Filter out RAX==0x1 (junk).
// rbx: Damage source (Either PlayerCharacter or Actor)
// Filter out RBX==0x0 (environmental sourced).
// UNIQUE AOB: C5 FA 58 D7 C5 FA 11 55 48
define(omnifyApocalypseHook,"Starfield.exe"+24C161D)

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
    cmp rax,0x3B0
    pop rax
    jne initiateApocalypseOriginalCode    
    sub rsp,10
    movdqu [rsp],xmm2
    push rax
    push rbx
    push rcx
    // Make damage offset unsigned and then load it as the first common parameter.
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
initiateApocalypseCleanup:
    pop rcx
    pop rbx
    pop rax
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

// Launch our ship.
verticalTeleportitisDisplacementX:
    dd (float)100.0


[DISABLE]

// Cleanup of omnifyApocalypseHook
omnifyApocalypseHook:
    db C5 FA 58 D7 C5 FA 11 55 48

unregistersymbol(omnifyApocalypseHook)

dealloc(initiateApocalypse)


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