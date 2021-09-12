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
// UNIQUE AOB: 36 48 6B 41 20 64
define(omniPlayerHealthHook,"nioh2.exe"+9B7A60)

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
define(omniPlayerStaminaHook,"nioh2.exe"+7C2E95)

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
// [rax+F0-F8]: Player's coordinates. Y-coordinate is vertical.
// UNIQUE AOB: 0F 10 80 00 01 00 00 0F 11 81  
// Correct instruction will be four instructions above the returned result.
define(omniPlayerLocationHook,"nioh2.exe"+81C595)

assert(omniPlayerLocationHook,0F 10 80 F0 00 00 00)
alloc(getPlayerLocation,$1000,omniPlayerLocationHook)
alloc(playerLocation,8)

registersymbol(playerLocation)
registersymbol(omniPlayerLocationHook)

getPlayerLocation:
    mov [playerLocation],rax
getPlayerLocationOriginalCode:
    movups xmm0,[rax+000000F0]
    jmp getPlayerLocationReturn

omniPlayerLocationHook:
    jmp getPlayerLocation
    nop 2
getPlayerLocationReturn:


// Gets the player's last location structure and ensures Omnified changes to the player's vertical position
// is properly reflected.
// [rsp+120] | {rsp+132}: Points to root structure of NPC the coordinates belong to.
// [rdi+C8]: Player's last known y-coordinate on solid ground.
// UNIQUE AOB: 89 87 C8 00 00 00 8B 47
// Correct instruction will be single result found in nioh2.exe (not nvd3dumx.dll).
define(omniPlayerLastLocationHook,"nioh2.exe"+8549BB)

assert(omniPlayerLastLocationHook,89 87 C8 00 00 00)
alloc(getPlayerLastLocation,$1000,omniPlayerLastLocationHook)
alloc(playerLastLocation,8)

registersymbol(playerLastLocation)
registersymbol(omniPlayerLastLocationHook)

getPlayerLastLocation:
    pushf
    // The player health structure must be initialized in order for us to identify the player's last location 
    // structure.
    push rax
    mov rax,playerHealth
    cmp [rax],0
    pop rax
    je getPlayerLastLocationOriginalCode
    push rbx
    push rcx
    mov rbx,playerHealth
    mov rcx,[rbx]
    mov rbx,[rsp+132]
    // The base of the health structure points to the character's root structure.
    cmp [rcx],rbx
    jne getPlayerLastLocationCleanup
    mov [playerLastLocation],rdi    
getPlayerLastLocationCleanup:
    pop rcx
    pop rbx
getPlayerLastLocationOriginalCode:
    popf
    mov [rdi+000000C8],eax
    jmp getPlayerLastLocationReturn

omniPlayerLastLocationHook:
    jmp getPlayerLastLocation
    nop 
getPlayerLastLocationReturn:


// Gets the structure containing the game's options.
// [rax+3C]: Pause when window is inactive.
// UNIQUE AOB: 8B 83 80 00 00 00 83 E8 03
// Correct instruction is 13 instructions down from the returned result.
define(omniGameOptionsHook,"nioh2.exe"+103B628)

assert(omniGameOptionsHook,80 78 3C 00 74 6D)
alloc(getGameOptions,$1000,omniGameOptionsHook)
alloc(gameOptions,8)
alloc(pauseWhenInactive,8)

registersymbol(pauseWhenInactive)
registersymbol(gameOptions)
registersymbol(omniGameOptionsHook)

getGameOptions:
    pushf
    mov [gameOptions],rax
    push rbx
    mov rbx,[pauseWhenInactive]
    mov [rax+3C],rbx
    pop rbx
getGameOptionsOriginalCode:
    popf
    cmp byte ptr [rax+3C],00
    je nioh2.exe+103B69B
    jmp getGameOptionsReturn

omniGameOptionsHook:
    jmp getGameOptions
    nop 
getGameOptionsReturn:


pauseWhenInactive:
    dd 0


// Processes Omnified events during execution of the location update code for the player.
define(omnifyLocationUpdateHook,"nioh2.exe"+801863)

assert(omnifyLocationUpdateHook,66 0F 7F 81 F0 00 00 00)
alloc(updateLocation,$1000,omnifyLocationUpdateHook)
alloc(teleportLocation,16)
alloc(framesToSkip,8)

registersymbol(omnifyLocationUpdateHook)

updateLocation:
    pushf
    // Since we need to update it upon a teleport occurring, the last location structure player is required for further
    // processing.
    push rax
    mov rax,playerLastLocation
    cmp [rax],0
    pop rax
    je updateLocationOriginalCode
    // Only events pertaining to the player are processed here.
    push rax
    mov rax,playerLocation
    cmp [rax],rcx
    pop rax
    jne updateLocationOriginalCode
    // Upon a teleport, we engage in a movement frame skip sequence, this is so the desired teleport coordinates actually get
    // committed to the player's location (and stay there); otherwise, an army of validation-related code will revert the coordinates
    // depending on the situation.
    cmp [framesToSkip],0
    jg skipMovementFrame
    push rax
    mov rax,teleported
    cmp [rax],1
    pop rax
    jne updateLocationOriginalCode
    push rax
    push rbx
    push rcx
    mov rax,teleported
    mov [rax],0    
    mov [framesToSkip],#20
    mov rbx,playerLastLocation
    mov rax,[rbx]
    // Need to set our last location (vertically) so that proper fall damage will occur if we just got Tom Petty'd.
    mov rcx,teleportedY
    mov rbx,[rcx]
    mov [rax+C8],rbx
    pop rcx
    pop rbx
    pop rax    
skipMovementFrame:    
    dec [framesToSkip]        
    push rax
    push rbx        
    push rcx
    // Simply ignoring the updated coordinates in xmm0 is not enough, as other validation code might've already reverted our
    // source-of-truth coordinates. So, we load up the teleport coordinates set during the Apocalypse pass.
    mov rcx,teleportLocation
    movdqu [rcx],xmm0
    mov rax,teleportedX
    mov rbx,[rax]
    mov [rcx],rbx
    mov rax,teleportedY
    mov rbx,[rax]
    mov [rcx+4],rbx
    mov rax,teleportedZ
    mov rbx,[rax]
    mov [rcx+8],rbx    
    movdqu xmm0,[rcx]
    pop rcx
    pop rbx
    pop rax    
updateLocationOriginalCode:
    popf
    movdqa [rcx+000000F0],xmm0
    jmp updateLocationReturn

omnifyLocationUpdateHook:
    jmp updateLocation
    nop 3
updateLocationReturn:


// Initiates the Apocalypse system.
// This is Nioh 2's damage application code.
// [rbx+10]: Working health.
// edi: Damage amount.
// rbx: Target health structure.
// UNIQUE AOB: 8B 43 10 2B C7
// Correct instruction will be single result found in nioh2.exe (not the other two DLL's).
define(omnifyApocalypseHook,"nioh2.exe"+79C590)

assert(omnifyApocalypseHook,8B 43 10 2B C7)
alloc(initiateApocalypse,$1000,omnifyApocalypseHook)

registersymbol(omnifyApocalypseHook)

initiateApocalypse:
    pushf
    // An empty r12 register indicates the damage originates from falling.
    // We don't want this to trigger Apocalypse, as it may have been Apocalypse that caused the falling...
    cmp r12,0
    je initiateApocalypseOriginalCode
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


negativeVerticalDisplacementEnabled:
    dd 0

teleportitisDisplacementX:
    dd (float)180.0


// Initiates the Predator system.
// [rdx+0-8]: Movement offsets for x, y, and z-coordinates respectively.
// [rbx]: Target location structure
// UNIQUE AOB: F3 0F 58 02 F3 0F 11 81 80 01 00 00
define(omnifyPredatorHook,"nioh2.exe"+852588)

assert(omnifyPredatorHook,F3 0F 58 02 F3 0F 11 81 80 01 00 00)
alloc(initiatePredator,$1000,omnifyPredatorHook)
alloc(identityValue,8)

registersymbol(identityValue)
registersymbol(omnifyPredatorHook)

initiatePredator:
    pushf
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je initiatePredatorOriginalCode
    // Make sure the player isn't being treated as an enemy NPC!
    push rax
    mov rax,playerLocation
    cmp [rax],rbx
    pop rax
    je applyPlayerSpeed
    // Backing up the registers used to hold Predator system output, as well as an SSE to hold some of the parameters 
    // we'll be passing.
    sub rsp,10
    movdqu [rsp],xmm0
    push rax
    push rbx
    push rcx
    // The first parameter is our player's coordinates.
    mov rax,playerLocation
    mov rcx,[rax]
    push [rcx+F0]
    push [rcx+F8]
    // The next parameter is the target NPC's coordinates.
    push [rbx+F0]
    push [rbx+F8]
    // The third parameter is the NPC's dimensional scales. Jury is still out whether this game has True Scaling, so we'll
    // just be passing a good ol' identity matrix for now.
    movss xmm0,[identityValue]
    shufps xmm0,xmm0,0
    sub rsp,10
    movdqu [rsp],xmm0
    // The fourth parameter is the NPC's movement offsets. Wow this has been easy!
    push [rdx]
    push [rdx+8]
    call executePredator
    // Now we just take the updated movement offsets and dump them back into [rdx].
    mov [rdx],eax
    mov [rdx+4],ebx
    mov [rdx+8],ecx
    pop rcx
    pop rbx
    pop rax
    movdqu xmm0,[rsp]
    add rsp,10
    jmp initiatePredatorOriginalCode
applyPlayerSpeed:

initiatePredatorOriginalCode:
    popf
    addss xmm0,[rdx]
    movss [rcx+00000180],xmm0
    jmp initiatePredatorReturn

omnifyPredatorHook:
    jmp initiatePredator
    nop 7
initiatePredatorReturn:


identityValue:
    dd (float)1.0

aggroDistance:
    dd (float)1000.0

threatDistance:
    dd (float)200.0

positiveLimit:
    dd (float)1000.0

negativeLimit:
    dd (float)-1000.0


// Initiates the Abomnification system.
// This only polls NPC coordinates.
// [rsi+140]: Height
// [rsi+144]: Depth
// [rsi+148]: Width
// UNIQUE AOB: F3 0F 10 B6 F0 00 00 00 F3
define(omnifyAbomnificationHook,"nioh2.exe"+8A7618)

assert(omnifyAbomnificationHook,F3 0F 10 B6 F0 00 00 00)
alloc(initiateAbomnification,$1000,omnifyAbomnificationHook)

registersymbol(omnifyAbomnificationHook)

initiateAbomnification:
    pushf
    // Back up the registers used as outputs of the Abomnification system.
    push rax
    push rbx
    push rcx
    // Push the address to the creature's location structure as its identifying
    // address to the stack.
    push rsi
    call executeAbomnification
    // Load the Abomnified scales into the creature's location structure.
    mov [rsi+148],eax
    mov [rsi+140],ebx
    mov [rsi+144],ecx
    pop rcx
    pop rbx
    pop rax
initiateAbomnificationOriginalCode:
    popf
    movss xmm6,[rsi+000000F0]
    jmp initiateAbomnificationReturn

omnifyAbomnificationHook:
    jmp initiateAbomnification
    nop 3
initiateAbomnificationReturn:


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
    db 0F 10 80 F0 00 00 00

unregistersymbol(omniPlayerLocationHook)
unregistersymbol(playerLocation)

dealloc(playerLocation)
dealloc(getPlayerLocation)


// Cleanup of omniPlayerLastLocationHook
omniPlayerLastLocationHook:
    db 89 87 C8 00 00 00

unregistersymbol(omniPlayerLastLocationHook)
unregistersymbol(playerLastLocation)

dealloc(playerLastLocation)
dealloc(getPlayerLastLocation)


// Cleanup of omniGameOptionsHook
omniGameOptionsHook:
    db 80 78 3C 00 74 6D

unregistersymbol(omniGameOptionsHook)
unregistersymbol(gameOptions)
unregistersymbol(pauseWhenInactive)

dealloc(pauseWhenInactive)
dealloc(gameOptions)
dealloc(getGameOptions)


// Cleanup of omnifyLocationUpdateHook
omnifyLocationUpdateHook:
    db 66 0F 7F 81 F0 00 00 00

unregistersymbol(omnifyLocationUpdateHook)
dealloc(framesToSkip)
dealloc(teleportLocation)
dealloc(updateLocation)


// Cleanup of omnifyApocalypseHook
omnifyApocalypseHook:
    db 8B 43 10 2B C7

unregistersymbol(omnifyApocalypseHook)

dealloc(initiateApocalypse)


// Cleanup of omnifyPredatorHook
omnifyPredatorHook:
    db F3 0F 58 02 F3 0F 11 81 80 01 00 00

unregistersymbol(omnifyPredatorHook)
unregistersymbol(identityValue)

dealloc(identityValue)
dealloc(initiatePredator)


// Cleanup of omnifyAbomnificationHook
omnifyAbomnificationHook:
    db F3 0F 10 B6 F0 00 00 00

unregistersymbol(omnifyAbomnificationHook)

dealloc(initiateAbomnification)