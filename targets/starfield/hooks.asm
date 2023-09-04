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

// Gets the player's root structure.
// Actor values blob is at [player]+0x2A0
// Maximum health is located by matching a known ActorValueInfo pointer to an entry at actor values blob.
// Need to figure out how to get discriminator value!
// UNIQUE AOB: 48 8B 01 48 8B FA 33 DB FF 90 E0
define(omniPlayerHook,"Starfield.exe"+1A096CE)

assert(omniPlayerHook,48 8B 01 48 8B FA)
alloc(getPlayer,$1000,omniPlayerHook)
alloc(player,8)

registersymbol(player)
registersymbol(omniPlayerHook)

getPlayer:
    pushf
    mov [player],rcx
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

dealloc(player)
dealloc(getPlayer)