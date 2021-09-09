//----------------------------------------------------------------------
// Hooks for Omnified Nioh 2
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2021 Bad Echo LLC
//
// Bad Echo Technologies are licensed under a
// Creative Commons Attribution-NonCommercial 4.0 International License.
//
// See accompanying file LICENSE.md or a copy at:
// http://creativecommons.org/licenses/by-nc/4.0/
//----------------------------------------------------------------------

// Gets the player's health structure.
// Polls player health exclusively. No filtering required.
// [rcx+20]: Current health.
// [rcx+18]: Maximum health.
// UNIQUE AOB: 3B 48 6B 41 20 64
define(omniPlayerHealthHook,"nioh2.exe"+C700E0)

assert(omniPlayerHealthHook,48 6B 41 20 64)
alloc(getPlayerHealth,$1000,omniPlayerHealthHook)
alloc(playerHealth,8)

registersymbol(playerHealth)
registersymbol(omniPlayerHealthHook)

getPlayerHealth:
    mov [playerHealth],rcx
getPlayerHealthOriginalCode:
    imul rax,[rcx+20],64
    jmp getPlayerHealthReturn

omniPlayerHealthHook:
    jmp getPlayerHealth
getPlayerHealthReturn:


// Gets the player's stamina (Ki) structure.
// Polls player stamina exclusively. No filtering required.
// Unlike health, stamina is stored as a float.
// [rcx+8]: Current stamina.
// [rcx+C]: Maximum stamina.
// UNIQUE AOB: F3 0F 58 41 08 C3 CC CC CC CC CC 48
define(omniPlayerStaminaHook,"nioh2.exe"+9F0125)

assert(omniPlayerStaminaHook,F3 0F 58 41 08)
alloc(getPlayerStamina,$1000,omniPlayerStaminaHook)
alloc(playerStamina,8)

registersymbol(playerStamina)
registersymbol(omniPlayerStaminaHook)

getPlayerStamina:
    mov [playerStamina],rcx
getPlayerStaminaOriginalCode:
    addss xmm0,[rcx+08]
    jmp getPlayerStaminaReturn

omniPlayerStaminaHook:
    jmp getPlayerStamina
getPlayerStaminaReturn:


// Gets the player's location structure.
// Polls player coordinates exclusively. No filtering required.
// [r15+F0-F8]: Player's coordinates. Y-coordinate is vertical.
// UNIQUE AOB: D8 00 00 00 F3 41 0F 10 97 F0 00 00 00
define(omniPlayerLocationHook,"nioh2.exe"+C3B128)

assert(omniPlayerLocationHook,F3 41 0F 10 97 F0 00 00 00)
alloc(getPlayerLocation,$1000,omniPlayerLocationHook)
alloc(playerLocation,8)

registersymbol(playerLocation)
registersymbol(omniPlayerLocationHook)

getPlayerLocation:
    mov [playerLocation],r15
getPlayerLocationOriginalCode:
    movss xmm2,[r15+000000F0]
    jmp getPlayerLocationReturn

omniPlayerLocationHook:
    jmp getPlayerLocation
    nop 4
getPlayerLocationReturn:


// Initiates the Apocalypse system.
// This is Nioh 2's damage application code.
// [rbx+10]: Working health.
// edi: Damage amount.
// rbx: Target health structure.
// UNIQUE AOB: 8B 43 10 2B C7
define(omnifyApocalypseHook,"nioh2.exe"+9C4E10)

assert(omnifyApocalypseHook,8B 43 10 2B C7)
alloc(initiateApocalypse,$1000,omnifyApocalypseHook)

registersymbol(omnifyApocalypseHook)

initiateApocalypse:
    pushf
    // Ensure the required player data structures are initialized.
    push rax
    mov rax,playerHealth
    cmp [rax],0
    pop rax
    je initiateApocalypseOriginalCode
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je initiateApocalypseOriginalCode
    // Backing up a SSE register to hold converted floating point values for the health
    // and damage amount.
    sub rsp,10
    movdqu [rsp],xmm0
    // Backing up the outputs of the Apocalypse system.
    push rax
    push rbx
    // Backing up a register to hold the address pointed to by rbx, as we need to write one of our outputs to it
    // when all is said and done.
    push rcx    
    mov rcx,rbx    
    // Both Player and Enemy Apocalypse functions share the same first two parameters. 
    // Let's load them first before figuring out which subsystem to execute.
    // We'll need to convert the working health and damage amount values from being integer types to floating point types,
    // as this is the data type expected by the Apocalypse system.    
    cvtsi2ss xmm0,edi    
    // Load the damage amount parameter.
    sub rsp,8
    movd [rsp],xmm0
    mov rax,[rcx+10]
    cvtsi2ss xmm0,rax
    // Load the working health amount parameter.
    sub rsp,8
    movd [rsp],xmm0    
    // Now, we need to determine whether the player or an NPC is being damaged, and then from there execute the appropriate
    // Apocalypse subsystem.
    mov rbx,playerHealth
    // The target health structure being employed by this code is "misaligned" by 10 bytes.
    mov rax,[rbx]
    add rax,0x10
    cmp rax,rcx
    je initiatePlayerApocalypse
    jmp initiateEnemyApocalypse    
initiatePlayerApocalypse:        
    // Convert the maximum health for the player to the expected floating point form.
    // The maximum health will be found at [rcx+8] instead of [rcx+18] due to the previously mentioned "misalignment".
    mov rax,[rcx+8]
    cvtsi2ss xmm0,rax
    // Load the maximum health parameter.
    sub rsp,8
    movd [rsp],xmm0
    // Align the player's location coordinate structure so it begins at our x-coordinate and pass that as the final parameter.
    mov rax,playerLocation
    mov rbx,[rax]
    lea rax,[rbx+F0]
    push rax
    call executePlayerApocalypse
    jmp initiateApocalypseUpdateDamage
initiateEnemyApocalypse:
    call executeEnemyApocalypse
initiateApocalypseUpdateDamage:
    // To make use of the updated damage and working health amounts returned by the Apocalypse system,
    // we'll need to convert them both back to integer form.
    movd xmm0,eax
    cvtss2si edi,xmm0
    movd xmm0,ebx
    cvtss2si ebx,xmm0
    mov [rcx+10],ebx
initiateApocalypseCleanup:
    pop rcx
    pop rbx
    pop rax
    movdqu xmm0,[rsp]
    add rsp,10
initiateApocalypseOriginalCode:
    popf
    mov eax,[rbx+10]
    sub eax,edi
    jmp initiateApocalypseReturn

omnifyApocalypseHook:
    jmp initiateApocalypse
initiateApocalypseReturn:


[DISABLE]

// Cleanup of omniPlayerHealthHook
omniPlayerHealthHook:
    db 48 6B 41 20 64

unregistersymbol(omniPlayerHealthHook)
unregistersymbol(playerHealth)

dealloc(playerHealth)
dealloc(getPlayerHealth)


// Cleanup of omniPlayerStaminaHook
omniPlayerStaminaHook:
    db F3 0F 58 41 08

unregistersymbol(omniPlayerStaminaHook)
unregistersymbol(playerStamina)

dealloc(playerStamina)
dealloc(getPlayerStamina)


// Cleanup of omniPlayerLocationHook
omniPlayerLocationHook:
    db F3 41 0F 10 97 F0 00 00 00

unregistersymbol(omniPlayerLocationHook)
unregistersymbol(playerLocation)

dealloc(playerLocation)
dealloc(getPlayerLocation)


// Cleanup of omnifyApocalypseHook
omnifyApocalypseHook:
    db 8B 43 10 2B C7

unregistersymbol(omnifyApocalypseHook)

dealloc(initiateApocalypse)