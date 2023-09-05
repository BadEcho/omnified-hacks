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
// will be listed here:
//
// Known ActorValueInfo Types:
//  Maximum Health - 0x108
omniActorValueKeysHook+(DWORD)[omniActorValueKeysHook+3]+7:
actorValueKeys:

// Gets the player's root structure.
// Effective health is located at [player]+0x3B8 -- it is stored as an offset (seems to be either 0 or a negative value, which you add to the maximum health to get your health).
// Maximum health is an ActorValueInfo property whose key value can be found at [[actorValueKeys+0x108]+0xB0]+x0]
// In order to find ActorValueInfo values, search in [player+0x2A0], for specific key at [entry+0x0] every 16 bytes. Value is at matched [entry+0x8].
// UNIQUE AOB: 48 8B 01 48 8B FA 33 DB FF 90 E0
define(omniPlayerHook,"Starfield.exe"+1A096CE)

assert(omniPlayerHook,48 8B 01 48 8B FA)
alloc(getPlayer,$1000,omniPlayerHook)
alloc(player,8)
alloc(playerMaxHealth,8)

registersymbol(playerMaxHealth)
registersymbol(player)
registersymbol(omniPlayerHook)

getPlayer:
    pushf
    push rax
    push rbx
    push rdx
    push rsi
    mov [player],rcx    
    // Load the maximum health actor value key.
    mov rbx,[actorValueKeys+108]
    mov rax,[rbx+B0]
    mov rbx,[rax]    
    // Calculate the maximum possible entry address based on the number of entries stored at [player+0x298].
    mov rax,[rcx+298]
    mov rdx,10
    mul rdx
    add rax,[rcx+2A0]
    // Find the maximum health by searching in the ActorValueInfo property bag.
    mov rsi,[rcx+2A0]
nextActorValue:
    // Check if we're past the last ActorValueInfo entry.
    cmp rsi,rax
    jg getActorValueExit
    cmp rbx,[rsi]    
    je readActorValue
    add rsi,10
    jmp nextActorValue
readActorValue:
    mov rbx,[rsi+8]
    mov [playerMaxHealth],rbx
getActorValueExit:
    pop rsi
    pop rdx
    pop rbx
    pop rax
getPlayerOriginalCode:
    popf
    mov rax,[rcx]
    mov rdi,rdx
    jmp getPlayerReturn

omniPlayerHook:
    jmp getPlayer
    nop 
getPlayerReturn:

[DISABLE]

// Cleanup of omniPlayerHook
omniPlayerHook:
    db 48 8B 01 48 8B FA

unregistersymbol(omniPlayerHook)
unregistersymbol(player)
unregistersymbol(playerMaxHealth)

dealloc(playerMaxHealth)
dealloc(player)
dealloc(getPlayer)

// Cleanup of omniActorValueKeysHook
unregistersymbol(actorValueKeys)