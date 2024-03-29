//----------------------------------------------------------------------
// Hooks for Omnified Cyberpunk 2077
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2023 Bad Echo LLC
// 
// Bad Echo Technologies are licensed under the
// GNU Affero General Public License v3.0.
//
// See accompanying file LICENSE.md or a copy at:
// https://www.gnu.org/licenses/agpl-3.0.html
//----------------------------------------------------------------------

// Gets the player's root and statistical structures.
// Magic numbers: 0x36E is Stamina's house address on Happy Stats Street.
// UNIQUE AOB: 48 C7 C5 FF FF FF FF 8B 46 0C 4D 8D 14 81 49 8B C1 49 8B D2 49 2B D1 48 C1 FA 02 48 85 D2
// AOB results in 3 matches, 6 instructions up should be 48 8D 71 50
define(omniPlayerHook,"Cyberpunk2077.exe"+1A965E8)

assert(omniPlayerHook,4C 8B 0E 48 C7 C5 FF FF FF FF)
alloc(getPlayer,$1000,omniPlayerHook)
alloc(player,8)
alloc(playerMaxStamina,8)
alloc(playerStaminaValue,8)

registersymbol(omniPlayerHook)
registersymbol(player)
registersymbol(playerMaxStamina)
registersymbol(playerStaminaValue)

getPlayer:
    pushf 
    // Isolate the player root structure through pinpointed comparing of comparable comparables.
    // This is a constant identifying another statistic that is constantly queried for.
    // We're going to piggyback off of it in order to find the statistics we care about.
    cmp r14,0x1CB
    jne getPlayerOriginalCode
    push rax 
    push rbx
    push rcx
    push rdx
    push rdi
    mov rax,player
    mov [rax],rsi    
    // Load the "address book" for statistics.
    mov rax,[rsi]
    // Get the number of address book entries.
    mov ebx,[rsi+C]
    mov rcx,rbx    
    // This is the constant used to identify the stamina statistic.
    mov rdx,0x36E
searchStatistics:
    // Divide and conquer! Cleaveth the search areath in halfeth!
    mov rbx,rcx
    sar rbx,1
    // Check if the current element is what we're looking for.
    cmp [rax+rbx*4],edx
    // Save our position in case we need to search the upper half.
    lea rdi,[rax+rbx*4]
    jae moveToLowerHalf
    // The current element was below what we're looking for, so we move to the upper half.
    sub rcx,rbx
    sub rcx,0x1
    lea rax,[rdi+0x4]
    jmp isStatisticFound
moveToLowerHalf:
    mov rcx,rbx
isStatisticFound:
    test rcx,rcx
    // Continue the search unless we've found our match or have already looked everywhere
    // (leaving us with, yup, no match).
    jg searchStatistics
    // From my observations, the stamina statistic will always be found, additional logic
    // that will handle failed searches will be added if needed.
    mov rcx,[rsi]
    // rax holds the addressKey, we then have the base address of the address book subtracted from it.
    sub rax,rcx
    // Taking one half of this value gives us the index to the desired data in the statistics array.
    sar rax,2
    add rax,rax
    // Here's our statistics array.
    mov rcx,[rsi+0x10]    
    // And here's the address to our desired statistic. Hooray.
    lea rbx,[rcx+rax*8+0xC]
    // Let's create a pointer directly to the max stamina statistic.
    mov rax,playerMaxStamina
    // Is this a freshly allocated maximum stamina stat? If so, we'll load it and also set our current 
    // stamina value to reflect the maximum, as there is a very good chance that the active stamina structure 
    // has not been loaded yet, which leaves us with an ugly 0 current stamina value.
    cmp [rax],rbx
    je getPlayerCleanup
loadNewStamina:
    mov [rax],rbx
    mov rax,playerStaminaValue
    // Thankfully, no need to convert percentages here...whew...
    mov rcx,[rbx]
    mov [rax],rcx
getPlayerCleanup:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax    
getPlayerOriginalCode:
    popf
    mov r9,[rsi]
    mov rbp,FFFFFFFFFFFFFFFF
    jmp getPlayerReturn

omniPlayerHook:
    jmp getPlayer
    nop 5
getPlayerReturn:


// Gets the player's health structure.
// UNIQUE AOB: F3 0F 10 80 90 01 00 00 0F 54
define(omniPlayerHealthHook,"Cyberpunk2077.exe"+1C0159B)

assert(omniPlayerHealthHook,F3 0F 10 80 90 01 00 00)
alloc(getPlayerHealth,$1000,omniPlayerHealthHook)
alloc(playerHealth,8)
alloc(playerHealthValue,8)

registersymbol(omniPlayerHealthHook)
registersymbol(playerHealth)
registersymbol(playerHealthValue)

getPlayerHealth:
    pushf
    // Additional health filters to support Dum Dum lol.
    // Maybe not specific to Dum Dum, but his ass is when it
    // all started.
    push rax
    mov rax,r14
    cmp eax,-1
    pop rax    
    je getPlayerHealthOriginalCode
    push rax
    mov rax,r15
    cmp eax,-1
    pop rax
    je getPlayerHealthOriginalCode
    push rbx
    mov rbx,[rax+F0]
    cmp rbx,0x1000101
    pop rbx
    jne getPlayerHealthOriginalCode
    sub rsp,10
    movdqu [rsp],xmm0
    push rbx    
    mov rbx,playerHealth
    mov [rbx],rax
    // Convert the health percentage into a discrete value for display purposes.
    mov rbx,percentageDivisor    
    // We take the current health percentage and convert it into a useable percentage value (0-1).
    movss xmm0,[rax+190]
    divss xmm0,[rbx]
    // Multiplying this percentage by the maximum health gives us a discrete current health value.
    mulss xmm0,[rax+188]
    mov rbx,playerHealthValue
    movss [rbx],xmm0
    pop rbx
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerHealthOriginalCode:
    popf
    movss xmm0,[rax+00000190]
    jmp getPlayerHealthReturn

omniPlayerHealthHook:
    jmp getPlayerHealth
    nop 3
getPlayerHealthReturn:


// Gets the player's stamina structure.
// UNIQUE AOB: F3 0F 10 80 90 01 00 00 F3 0F 11 45
// Will have 2 results. The one we want has a "je" instruction preceding it.
define(omniPlayerStaminaHook,"Cyberpunk2077.exe"+1BFDFB8)

assert(omniPlayerStaminaHook,F3 0F 10 80 90 01 00 00)
alloc(getPlayerStamina,$1000,omniPlayerStaminaHook)
alloc(playerStamina,8)

registersymbol(omniPlayerStaminaHook)
registersymbol(playerStamina)

getPlayerStamina:
    pushf    
    cmp r8,0    
    je getPlayerStaminaOriginalCode
    // Player data will have a non-zero value stored at this location.
    push rbx
    mov rbx,[rax+F0]
    cmp rbx,0
    pop rbx
    je getPlayerStaminaOriginalCode
    sub rsp,10
    movdqu [rsp],xmm0
    push rbx
    mov rbx,playerHealth
    cmp [rbx],rax
    je getPlayerStaminaCleanup
    mov rbx,playerStamina
    mov [rbx],rax
    // Convert the stamina percentage into a discrete value for display purposes.
    mov rbx,percentageDivisor
    // We take the current stamina percentage and convert it into a useable percentage value (0-1).
    movss xmm0,[rax+190]
    divss xmm0,[rbx]
    // Multiplying this percentage by the maximum stamina gives us a discrete current stamina value.
    mulss xmm0,[rax+188]
    mov rbx,playerStaminaValue
    movss [rbx],xmm0
getPlayerStaminaCleanup:
    pop rbx
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerStaminaOriginalCode:
    popf
    movss xmm0,[rax+00000190]
    jmp getPlayerStaminaReturn

omniPlayerStaminaHook:
    jmp getPlayerStamina
    nop 3
getPlayerStaminaReturn:


// Gets the player's experience data structure.
// UNIQUE AOB: 49 8B C6 8B 6F 20 48 8B 3F 48 03 E8 48 8B D5 48 8B CF 48 8B 07 FF 50 38 48 8B 07 48 8B CF FF 50 20 3C 03
// AOB will give two results, the one we want is executing constantly when player idles.
define(omniPlayerExperienceDataHook,"Cyberpunk2077.exe"+21D0AD)

assert(omniPlayerExperienceDataHook,48 8B 3F 48 03 E8)
alloc(getPlayerExperienceData,$1000,omniPlayerExperienceDataHook)
alloc(playerExperienceData,8)

registersymbol(omniPlayerExperienceDataHook)
registersymbol(playerExperienceData)

getPlayerExperienceData:
    pushf
    cmp rcx,1
    jne getPlayerExperienceDataOriginalCode
    cmp rsi,4
    jne getPlayerExperienceDataOriginalCode
    cmp r8,0xC
    jne getPlayerExperienceDataOriginalCode
    push rax
    mov rax,playerExperienceData
    mov [rax],rdi
    pop rax
getPlayerExperienceDataOriginalCode:
    popf
    mov rdi,[rdi]
    add rbp,rax
    jmp getPlayerExperienceDataReturn

omniPlayerExperienceDataHook:
    jmp getPlayerExperienceData
    nop 
getPlayerExperienceDataReturn:


// Gets the player's experience and street cred.
// Discriminator is at r8. rcx contains base address for finding desired stat.
// UNIQUE AOB: 88 5E 63 48 85 C9
define(omniPlayerExperienceHook,"Cyberpunk2077.exe"+2A363D)

assert(omniPlayerExperienceHook,88 5E 63 48 85 C9)
alloc(getPlayerExperience,$1000,omniPlayerExperienceHook)
alloc(playerExperience,8)

registersymbol(omniPlayerExperienceHook)
registersymbol(playerExperience)

getPlayerExperience:
    pushf
    push rax
    mov rax,playerExperienceData
    cmp [rax],rdi
    pop rax
    jne getPlayerExperienceOriginalCode
    // r8 is 0xB if it's retrieving the experience.
    cmp r8,0xB
    jne getPlayerExperienceOriginalCode
    push rax
    push rbx
    mov rax,[rdi+20]
    add rax,rcx
    mov rbx,playerExperience
    mov [rbx],rax
    pop rbx
    pop rax
getPlayerExperienceOriginalCode:
    popf
    mov [rsi+63],bl
    test rcx,rcx
    jmp getPlayerExperienceReturn

omniPlayerExperienceHook:
    jmp getPlayerExperience
    nop
getPlayerExperienceReturn:


// Gets the player's money.
// The money is at [rcx+78]. This will execute one time, at least such that it satisfies
// our filter, one time at save game load.
// UNIQUE AOB: 48 8B 01 48 89 5C 24 40 FF 90 48
define(omniPlayerMoneyHook,"Cyberpunk2077.exe"+189BA4A)

assert(omniPlayerMoneyHook,48 8B 01 48 89 5C 24 40)
alloc(getPlayerMoney,$1000,omniPlayerMoneyHook)
alloc(playerMoney,8)

registersymbol(omniPlayerMoneyHook)
registersymbol(playerMoney)

getPlayerMoney:
    pushf
    cmp rax,0x3
    jne getPlayerMoneyOriginalCode
    cmp r13,0
    jne getPlayerMoneyOriginalCode
    mov [playerMoney],rcx
getPlayerMoneyOriginalCode:
    popf
    mov rax,[rcx]
    mov [rsp+40],rbx
    jmp getPlayerMoneyReturn

omniPlayerMoneyHook:
    jmp getPlayerMoney
    nop 3
getPlayerMoneyReturn:


// Get the player's location structure.
// UNIQUE AOB: 0F 10 81 10 02 00 00 F2 0F 10 89 20 02 00 00 0F 11 02 F3
define(omniPlayerLocationHook,"PhysX3CharacterKinematic_x64.dll"+1EE0)

assert(omniPlayerLocationHook,0F 10 81 10 02 00 00)
alloc(getPlayerLocation,$1000,omniPlayerLocationHook)
alloc(playerLocation,8)

registersymbol(omniPlayerLocationHook)
registersymbol(playerLocation)

getPlayerLocation:
    push rax
    mov rax,playerLocation
    mov [rax],rcx
    pop rax
getPlayerLocationOriginalCode:
    movups xmm0,[rcx+00000210]
    jmp getPlayerLocationReturn

omniPlayerLocationHook:
    jmp getPlayerLocation
    nop 2
getPlayerLocationReturn:


// Gets a structure for the player's location that contains values normalized to the NPC coordinate plane.
// UNIQUE AOB: F3 0F 5C 83 08 01 00 00
define(omniPlayerLocationNormalizedHook,"Cyberpunk2077.exe"+4B45FD)

assert(omniPlayerLocationNormalizedHook,F3 0F 5C 83 08 01 00 00)
alloc(getPlayerLocationNormalized,$1000,omniPlayerLocationNormalizedHook)
alloc(playerLocationNormalized,8)

registersymbol(omniPlayerLocationNormalizedHook)
registersymbol(playerLocationNormalized)

getPlayerLocationNormalized:
    push rax
    mov rax,playerLocationNormalized
    mov [rax],rbx
    pop rax
getPlayerLocationNormalizedOriginalCode:
    subss xmm0,[rbx+00000108]
    jmp getPlayerLocationNormalizedReturn

omniPlayerLocationNormalizedHook:
    jmp getPlayerLocationNormalized
    nop 3
getPlayerLocationNormalizedReturn:


// Gets the player's vehicle's coordinates.
// Coordinates are found starting at [rdx+10]
// UNIQUE AOB: 28 8B 02 89 01 8B 42 04
define(omniPlayerLocationVehicleHook,"PhysX3_x64.dll"+1D9C19)

assert(omniPlayerLocationVehicleHook,8B 02 89 01 8B 42 04)
alloc(getPlayerLocationVehicle,$1000,omniPlayerLocationVehicleHook)
alloc(playerLocationVehicle,8)
alloc(positiveVehicleDistanceTolerance,8)
alloc(negativeVehicleDistanceTolerance,8)

registersymbol(omniPlayerLocationVehicleHook)
registersymbol(playerLocationVehicle)

getPlayerLocationVehicle:
    pushf
    // Make sure our player's coordinate pointer has been initialized.
    push rax
    mov rax,playerLocation
    cmp [rax],0
    pop rax
    je getPlayerLocationVehicleOriginalCode
    // We'll need two SSE registers in order to convert from double to float and also to pass the parameters
    // correctly.
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm1
    // We'll need two CPU registers so we can dereference our player's location pointer, and also preserve
    // data in light of the coordinate distance call using EAX as an output.
    push rax
    push rbx
    mov rax,playerLocation
    mov rbx,[rax]
    // Convert the player's x and y coordinates to float.
    cvtpd2ps xmm0,[rbx+210]
    // Convert the player's z-coordinate to float.
    cvtsd2ss xmm1,[rbx+220]
    // Pass the first parameter, the player's coordinates, as if they were being passed as two m64 addresses.
    sub rsp,8
    movq [rsp],xmm0
    sub rsp,8
    movq [rsp],xmm1
    // Pass the second parameter, the reference coordinates.
    push [rdx+10]
    push [rdx+18]
    call findCoordinateDistance    
    movd xmm0,eax
    shr eax,1F
    test eax,eax
    jne checkNegativeVehicleDistanceTolerance
    ucomiss xmm0,[positiveVehicleDistanceTolerance]
    ja getPlayerLocationVehicleCleanup
    jmp registerNewPlayerLocationVehicle
checkNegativeVehicleDistanceTolerance:
    ucomiss xmm0,[negativeVehicleDistanceTolerance]
    jb getPlayerLocationVehicleCleanup
registerNewPlayerLocationVehicle:
    mov rax,playerLocationVehicle
    mov [rax],rdx
getPlayerLocationVehicleCleanup:
    pop rbx
    pop rax
    movdqu xmm1,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
getPlayerLocationVehicleOriginalCode:
    popf
    mov eax,[rdx]
    mov [rcx],eax
    mov eax,[rdx+04]
    jmp getPlayerLocationVehicleReturn

omniPlayerLocationVehicleHook:
    jmp getPlayerLocationVehicle
    nop 2
getPlayerLocationVehicleReturn:


positiveVehicleDistanceTolerance:
    dd (float)2.0

negativeVehicleDistanceTolerance:
    dd (float)-2.0


// Gets the player's magazine prior to a gun firing.
// UNIQUE AOB: 0F B7 8E 50 03 00 00
define(omniPlayerMagazineBeforeFireHook,"Cyberpunk2077.exe"+1B95E93)

assert(omniPlayerMagazineBeforeFireHook,0F B7 8E 50 03 00 00)
alloc(getPlayerMagazine,$1000,omniPlayerMagazineBeforeFireHook)
alloc(playerMagazine,8)

registersymbol(omniPlayerMagazineBeforeFireHook)
registersymbol(playerMagazine)

getPlayerMagazine:
    pushf
    cmp r12,0
    jne getPlayerMagazineOriginalCode
    cmp r13,0
    jne getPlayerMagazineOriginalCode
    push rax
    mov rax,playerMagazine
    mov [rax],rsi
    pop rax
getPlayerMagazineOriginalCode:
    popf
    movzx ecx,word ptr [rsi+00000350]
    jmp getPlayerMagazineReturn

omniPlayerMagazineBeforeFireHook:
    jmp getPlayerMagazine
    nop 2
getPlayerMagazineReturn:


// Gets the player's magazine when swapping to a new weapon.
// UNIQUE AOB: 41 89 3F 48 8B BE D0 02 00 00
define(omniPlayerMagazineAfterSwapHook,"Cyberpunk2077.exe"+1B98968)

assert(omniPlayerMagazineAfterSwapHook,41 89 3F 48 8B BE D0 02 00 00)
alloc(getPlayerMagazineAfterSwap,$1000,omniPlayerMagazineAfterSwapHook)

registersymbol(omniPlayerMagazineAfterSwapHook)

getPlayerMagazineAfterSwap:
    pushf
    cmp r13d,-0x1
    je getPlayerMagazineAfterSwapOriginalCode
    push rax
    push rbx
    mov rax,playerMagazine
    mov rbx,r15
    sub rbx,0x350
    mov [rax],rbx
    pop rbx
    pop rax    
getPlayerMagazineAfterSwapOriginalCode:
    popf
    mov [r15],edi
    mov rdi,[rsi+000002D0]
    jmp getPlayerMagazineAfterSwapReturn

omniPlayerMagazineAfterSwapHook:
    jmp getPlayerMagazineAfterSwap
    nop 5
getPlayerMagazineAfterSwapReturn:


// Detects when the game is paused.
// The game is considered "paused" when the player is in the escape menu.
// The game is not considered "paused" when character-related screens such as
// stats, inventory, or the map are open.
// UNIQUE AOB: 80 79 08 00 ** ** C6 41 08 01
define(omniDetectPausedGame,"Cyberpunk2077.exe"+28370F0)

assert(omniDetectPausedGame,80 79 08 00 75 04)
alloc(detectGamePaused,$1000,omniDetectPausedGame)
alloc(gamePaused,8)

registersymbol(omniDetectPausedGame)
registersymbol(gamePaused)

detectGamePaused:
    push rax
    mov rax,gamePaused
    mov [rax],1
    pop rax
detectGamePausedOriginalCode:
    cmp byte ptr [rcx+08],00
    jmp detectGamePausedReturn

omniDetectPausedGame:
    jmp detectGamePaused
    nop
detectGamePausedReturn:


// Detects when the game is unpaused.
// The game becomes unpaused when exiting the escape menu.
define(omniDetectUnpausedGame,"Cyberpunk2077.exe"+2836C50)

assert(omniDetectUnpausedGame,80 79 08 00 74 04)
alloc(detectGameUnpaused,$1000,omniDetectUnpausedGame)

registersymbol(omniDetectUnpausedGame)

detectGameUnpaused:
    push rax
    mov rax,gamePaused
    mov [rax],0
    pop rax
detectGameUnpausedOriginalCode:
    cmp byte ptr [rcx+08],00
    je Cyberpunk2077.exe+2836C5A 
    jmp detectGameUnpausedReturn

omniDetectUnpausedGame:
    jmp detectGameUnpaused
    nop
detectGameUnpausedReturn:


// Hooks into the vitals update code to perform tasks such as player melee hit detection and stamina
// discrete value updates.
// UNIQUE AOB: F3 0F 11 82 90 01 00 00
define(omnifyPlayerVitalsUpdateHook,"Cyberpunk2077.exe"+1A50F6A)

assert(omnifyPlayerVitalsUpdateHook,F3 0F 11 82 90 01 00 00)
alloc(playerVitalsUpdate,$1000,omnifyPlayerVitalsUpdateHook)

registersymbol(omnifyPlayerVitalsUpdateHook)

playerVitalsUpdate:
    pushf
    // Make sure stamina has been initialized.
    push rax
    mov rax,playerStamina
    cmp [rax],rdx
    pop rax
    jne playerVitalsUpdateOriginalCode    
    sub rsp,10
    movdqu [rsp],xmm1
    push rax
processStamina:    
    // Convert the stamina percentage into a discrete value for display purposes.
    mov rax,percentageDivisor
    // We take the current stamina percentage and convert it into a useable percentage value (0-1).
    movss xmm1,xmm0
    divss xmm1,[rax]
    // Multiplying this percentage by the maximum stamina gives us a discrete current stamina value.
    mulss xmm1,[rdx+188]
    mov rax,playerStaminaValue
    movss [rax],xmm1       
playerVitalsUpdateCleanup:
    pop rax
    movdqu xmm1,[rsp]
    add rsp,10
playerVitalsUpdateOriginalCode:
    popf
    movss [rdx+00000190],xmm0
    jmp playerVitalsUpdateReturn

omnifyPlayerVitalsUpdateHook:
    jmp playerVitalsUpdate
    nop 3
playerVitalsUpdateReturn:


// Hooks into the player's location update function, allowing us to prevent the player physics system 
// from interfering with teleportitis effects.
// Current values for x and y are located at [rsi+208].
// Updated values for x and y are located at [r15+08].
// Current values for z are located at [rsi+218].
// Updated values for z are located at [r15+18].
// UNIQUE AOB: 41 0F 10 47 08
define(omnifyPlayerLocationUpdateHook,"PhysX3CharacterKinematic_x64.dll"+7B8D)

assert(omnifyPlayerLocationUpdateHook,41 0F 10 47 08)
alloc(playerLocationUpdate,$1000,omnifyPlayerLocationUpdateHook)
alloc(movementFramesToSkip,8)

registersymbol(omnifyPlayerLocationUpdateHook)

playerLocationUpdate:
    pushf
    sub rsp,10
    movdqu [rsp],xmm0
    push rax
    mov rax,movementFramesToSkip
    cmp [rax],0
    pop rax    
    jg skipMovementFrame
    jmp checkForTeleported
skipMovementFrame:
    push rax
    mov rax,movementFramesToSkip
    dec [rax]
    pop rax
    movupd xmm0,[rsi+208]
    movupd [r15+08],xmm0
    movupd xmm0,[rsi+218]
    movupd [r15+18],xmm0
    jmp playerLocationUpdateCleanup
checkForTeleported:
    push rax
    mov rax,teleported
    cmp [rax],1
    pop rax    
    jne playerLocationUpdateCleanup
    push rax
    mov rax,teleported
    mov [rax],0    
    mov rax,movementFramesToSkip
    mov [rax],2
    pop rax
    jmp skipMovementFrame
playerLocationUpdateCleanup:
    movdqu xmm0,[rsp]
    add rsp,10
playerLocationUpdateOriginalCode:
    popf
    movups xmm0,[r15+08]
    jmp playerLocationUpdateReturn

omnifyPlayerLocationUpdateHook:
    jmp playerLocationUpdate
playerLocationUpdateReturn:


// Gets the player's identifying attack structure.
// UNIQUE AOB: 48 8B 01 FF 90 20 01 00 00 48 8D 4B
define(omniPlayerAttackHook,"Cyberpunk2077.exe"+2DFB970)

assert(omniPlayerAttackHook,48 8B 01 FF 90 20 01 00 00)
alloc(getPlayerAttack,$1000,omniPlayerAttackHook)
alloc(playerAttack,8)

registersymbol(omniPlayerAttackHook)
registersymbol(playerAttack)

getPlayerAttack:
    push rax
    mov rax,playerAttack
    mov [rax],rcx
    pop rax
getPlayerAttackOriginalCode:
    mov rax,[rcx]
    call qword ptr [rax+00000120]
    jmp getPlayerAttackReturn

omniPlayerAttackHook:
    jmp getPlayerAttack
    nop 4
getPlayerAttackReturn:


// Initiates the Apocalypse system.
// xmm1: Damage percentage.
// [rcx+190]: Working health percentage.
// UNIQUE AOB: F3 0F 58 89 90 01 00 00 45
define(omnifyApocalypseHook,"Cyberpunk2077.exe"+1A4D9F0)

assert(omnifyApocalypseHook,F3 0F 58 89 90 01 00 00)
alloc(initiateApocalypse,$1000,omnifyApocalypseHook)
alloc(vehicleDamageX,8)

registersymbol(omnifyApocalypseHook)
registersymbol(vehicleDamageX)

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
    // Changes to stamina are also tallied here. We only care about health.
    push rax
    mov rax,playerStamina
    cmp [rax],rcx
    pop rax
    je initiateApocalypseOriginalCode
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm2
    push rax
    push rbx
    // Convert the damage percentage into a discrete value.    
    mov rax,percentageDivisor
    movss xmm2,xmm1
    divss xmm2,[rax]
    mulss xmm2,[rcx+188]
    mov rax,negativeOne
    mulss xmm2,[rax]       
    // Convert the working health percentage into a discrete value.
    movss xmm0,[rcx+190]    
    mov rax, percentageDivisor
    divss xmm0,[rax]
    // Multiply the percentage by the maximum health.
    mulss xmm0,[rcx+188]      
    // Check if the player is being damaged.
    mov rax,playerHealth
    cmp [rax],rcx
    je initiatePlayerApocalypse
    // The temporary working memory register at rdi points to an identifying
    // attack source.
    mov rax,[rdi+10]
    mov rbx,playerAttack
    cmp [rbx],rax
    jne initiateApocalypseCleanup    
    // The value found at this location in the health structure will be zero for vehicles.
    mov eax,[rcx+18C]
    cmp eax,0
    jne initiateEnemyApocalypse
    // If this is zero, then it is most likely "boss armor", which we're not going to track as their health.
    mov rax,[rcx+170]
    cmp eax,0
    je initiateApocalypseUpdateDamage
    cmp eax,0x01000001
    jne initiateEnemyApocalypse
    // We're damaging a vehicle. Let the Carpocalypse commence.
    mulss xmm2,[vehicleDamageX]
    movd eax,xmm2
    movd ebx,xmm0    
    jmp initiateApocalypseUpdateDamage
initiatePlayerApocalypse:
    // Load the damage amount parameter.
    sub rsp,8
    movd [rsp],xmm2
    // Load the working health amount parameter.
    sub rsp,8
    movd [rsp],xmm0
    // Load the maximum health amount parameter.
    push [rcx+188]
    // Align the player's location structure at the x-coordinate.
    mov rax,playerLocation
    mov rbx,[rax]
    lea rax,[rbx+210]
    push rax
    call executePlayerApocalypse    
    jmp initiateApocalypseUpdateDamage
initiateEnemyApocalypse:
    // Load the damage amount parameter.    
    sub rsp,8
    movd [rsp],xmm2
    // Load the working health amount parameter.
    sub rsp,8
    movd [rsp],xmm0
    call executeEnemyApocalypse
initiateApocalypseUpdateDamage:
    movd xmm1,eax
    divss xmm1,[rcx+188]
    mov rax,percentageDivisor
    mulss xmm1,[rax]
    mov rax,negativeOne
    mulss xmm1,[rax]
    movd xmm0,ebx
    divss xmm0,[rcx+188]
    mov rax,percentageDivisor
    mulss xmm0,[rax]
    movss [rcx+190],xmm0
initiateApocalypseCleanup:
    pop rbx
    pop rax
    movdqu xmm2,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
initiateApocalypseOriginalCode:
    popf
    addss xmm1,[rcx+00000190]
    jmp initiateApocalypseReturn

omnifyApocalypseHook:
    jmp initiateApocalypse
    nop 3
initiateApocalypseReturn:


damageThreshold:
    dd (float)0.2

coordinatesAreDoubles:
    dd 1

negativeVerticalDisplacementEnabled:
    dd 0

yIsVertical:
    dd 0

teleportitisDisplacementX:
    dd (float)0.5

verticalTeleportitisDisplacementX:
    dd (float)3.25

vehicleDamageX:
    dd (float)50.0


// Initiates the Predator system for NPCs.
// Sadly this only applies to simple NPCs you can find wandering Night City in the open world.
// Cyberpunk 2077 has overly strict pregenerated pathing for NPCs with complex movement.
// These NPCs must adhere to the correct point along their pregenerated paths at a particular
// point in time. 
// The Predator system only supports movment systems that feature dynamic pathing adherence,
// where paths are evaluted per movement frame. Remember, one of the tenets of the Predator system
// is that the speed is determined by where the player is in conjunction to where the the enemy is
// and the direction the enemy is moving. This is not possible to determine ahead of time, which
// you would need to do with a pregenerated path, as it would require seeing into the future.
//
// Support for non-dynamic, strict pathing adherent movement systems will be added to the Predator
// system if I come across this kind of system in any additional games, or if any game made by
// Hidetaki Miyazaki features it. It would require generating our own paths and ignoring the corrective
// offsets being offered to us by the game.
// UNIQUE AOB: E0 0F 58 20 0F 28 D4
// [rax]: Working desired coordinates, xmm4: Movement offsets
define(omnifyPredatorHook,"Cyberpunk2077.exe"+1C9EEB8)

assert(omnifyPredatorHook,0F 58 20 0F 28 D4)
alloc(initiatePredator,$1000,omnifyPredatorHook)
alloc(disablePredator,8)
alloc(identityValue,8)
alloc(verticalBoost,8)

registersymbol(omnifyPredatorHook)
registersymbol(disablePredator)
registersymbol(verticalBoost)

initiatePredator:
    pushf
    // The normalized player location coordinates are required before we can engage the
    // Predator system.    
    push rax
    mov rax,playerLocationNormalized
    cmp [rax],0
    pop rax
    je initiatePredatorOriginalCode
    cmp [disablePredator],1
    je initiatePredatorOriginalCode
    // Make sure we backup the registers Predator writes to -- we'll need an additional SSE register
    // to pass the target's coordinates as parameters to the Predator function.
    sub rsp,10
    movdqu [rsp],xmm0
    push rax
    push rbx
    push rcx
    mov rbx,playerLocationNormalized
    mov rcx,[rbx]
    // The first parameter is our player's coordinates. These normalized coordinates, from which our x-coordinate
    // can be found at 0x108, are comparable to NPC coordinates as they exist on the NPC coordinate plane, which 
    // is a completely separate coordinate plane from whether the player's source-of-truth coordinates live.
    push [rcx+108]
    push [rcx+110]
    // The next parameter is the target NPC's coordinates. Note that these are not directly related to the
    // NPC's source-of-truth coordinates, but rather another set that I termed the "desired" coordinates. These
    // are independently tracked and managed by the game, and while not actually the source-of-truth, they essentially
    // become so indirectly as the game will always push changes to these as changes to the source-of-truth coordinates.
    push [rax]
    push [rax+8]    
    // The third parameter is the NPC's dimensional scales. If this game offers True Scaling, then we'll update this
    // to provide real values; until such a discovery is made, we settle for an identity matrix of 1's.
    movss xmm0,[identityValue]
    shufps xmm0,xmm0,0
    sub rsp,10
    movdqu [rsp],xmm0
    // The final parameter is the NPC's movement offsets. The Predator system expects coordinate-related parameters to 
    // be pushed to the stack as two m64 addresses. Therefore, we place the highwords onto the SSE we backed up, and then
    // push the NPC's movement offsets, in order, as quadwords to the stack.
    movhlps xmm0,xmm4
    sub rsp,8
    movq [rsp],xmm4
    sub rsp,8
    movq [rsp],xmm0
    call executePredator
    // The updated movement offsets needed to be loaded onto the xmm4 register. We'll do this
    // by dumping the Predator return values onto the stack and then loading them onto xmm4.
    sub rsp,10
    // We dump xmm4 onto the stack first so we can preserve the fourth double word.
    movups [rsp],xmm4
    mov [rsp],eax
    mov [rsp+4],ebx
    // Optionally send the NPCs floating to the sky. For fun.
    movd xmm0,ecx
    addss xmm0,[verticalBoost]
    movd ecx,xmm0
    mov [rsp+8],ecx
    movups xmm4,[rsp]
    add rsp,10    
    pop rcx
    pop rbx
    pop rax
    movdqu xmm0,[rsp]
    add rsp,10
initiatePredatorOriginalCode:
    popf
    addps xmm4,[rax]
    movaps xmm2,xmm4
    jmp initiatePredatorReturn

omnifyPredatorHook:
    jmp initiatePredator
    nop
initiatePredatorReturn:


identityValue:
    dd (float)1.0

// This places the limits of the area of sketchiness at around 20 units, which is still well within the limits 
// of how far NPCs can spot the player. Around 10 units is where it seems like a good place to enable a charge of death.
aggroDistance:
    dd (float)10.0

// I'm able to hit things with my katana at ~1.1 units away from my player. We pad that number a bit in order to give the
// enemy the opportunity to come to a stop, and we have an ideal threat distance. Testing will be needed.
threatDistance:
    dd (float)1.5

disablePredator:
    dd 0

verticalBoost:
    dd (float)0.0


// Implements a modifier for the player's vehicle speed.
// Updated coordinate values are found starting at [rsi+60]
// Source-of-truth coordinate values are found starting at [rdx+10]
// UNIQUE AOB: 8B 46 60 89 42 10
define(omnifyPlayerVehicleSpeedHook,"PhysX3_x64.dll"+1D9C58)

assert(omnifyPlayerVehicleSpeedHook,8B 46 60 89 42 10)
alloc(setPlayerVehicleSpeed,$1000,omnifyPlayerVehicleSpeedHook)
alloc(playerVehicleSpeedX, 8)
alloc(playerVehicleVerticalSpeedX, 8)

registersymbol(omnifyPlayerVehicleSpeedHook)
registersymbol(playerVehicleSpeedX)
registersymbol(playerVehicleVerticalSpeedX)

setPlayerVehicleSpeed:
    pushf
    push rax
    mov rax,playerLocationVehicle
    cmp [rax],rdx
    pop rax
    jne setPlayerVehicleSpeedOriginalCode
    // This is essentially a hook into the location update code for the player's vehicle.
    // It is not used to update the location of vehicles driven by NPCs, sadly. It is also
    // more than likely responsible for updating the location of as-of-yet unknown entities,
    // however I haven't observed anything negatively affecting the gameplay experience
    // when manipulating the speed modifier. So, no need to figure out what these other entities are.
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm1
    sub rsp,10
    movdqu [rsp],xmm2
    // First we prime our multiplication register. We use a separate multiplier for the z-coordinate, as we often
    // do not want to multiply changes made to the veritcal axis, unless we wish to go flying off into the air.
    // Also, note that it is safe to leave the highest word set to 0, as it appears the the highest word is always
    // zero in both the updated and current location values.    
    movss xmm0,[playerVehicleSpeedX]
    shufps xmm0,xmm0,0
    movss xmm1,[playerVehicleVerticalSpeedX]
    movlhps xmm0,xmm1
    // End result is [playerVehicleSpeedX] | [playerVehicleSpeedX] | [playerVehicleVerticalSpeedX] | 0
    movups xmm2,[rdx+10]
    movups xmm1,[rsi+60]
    // First, we find the difference between the new and old location values.
    subps xmm1,xmm2
    // Then, we multiply the difference by our multiplier register.
    mulps xmm1,xmm0
    // Adding the multiplied difference to the original values gives us new, updated location values.
    addps xmm2,xmm1
    // We commit our new, updated location values.
    movups [rsi+60],xmm2    
    movdqu xmm2,[rsp]
    add rsp,10
    movdqu xmm1,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
setPlayerVehicleSpeedOriginalCode:
    popf
    mov eax,[rsi+60]
    mov [rdx+10],eax
    jmp setPlayerVehicleSpeedReturn

omnifyPlayerVehicleSpeedHook:
    jmp setPlayerVehicleSpeed
    nop 
setPlayerVehicleSpeedReturn:


playerVehicleSpeedX:
  dd (float)1.0

playerVehicleVerticalSpeedX:
  dd (float)1.0


// Detects when the player is driving a vehicle.
// UNIQUE AOB: F3 0F 11 B1 08 01 00 00
define(omniDetectPlayerDriving,"Cyberpunk2077.exe"+4B564A)

assert(omniDetectPlayerDriving,F3 0F 11 B1 08 01 00 00)
alloc(detectPlayerDriving,$1000,omniDetectPlayerDriving)
alloc(playerDriving,8)

registersymbol(omniDetectPlayerDriving)
registersymbol(playerDriving)

detectPlayerDriving:
    // See if we're moving; we only consider ourselves to be "driving" if we're moving.
    pushf
    push rax
    push rbx
    movd eax,xmm6
    // There will be slight deviations in the value even at rest, so we essentially truncate
    // the less significant parts of the value, only proceeding if the change itself is significant.
    shr eax,4
    mov ebx,[rcx+108]
    shr ebx,4    
    cmp eax,ebx
    pop rbx
    pop rax    
    je playerDrivingButNotMoving
    push rax
    mov rax,playerDriving
    mov [rax],1
    pop rax
    jmp detectPlayerDrivingOriginalCode
playerDrivingButNotMoving:
    push rax
    mov rax,playerDriving
    mov [rax],0
    pop rax
detectPlayerDrivingOriginalCode:
    popf
    movss [rcx+00000108],xmm6
    jmp detectPlayerDrivingReturn

omniDetectPlayerDriving:
    jmp detectPlayerDriving
    nop 3
detectPlayerDrivingReturn:


// Detects when the player is no longer driving a vehicle.
// UNIQUE AOB: F3 44 0F 11 93 08 01 00 00
define(omniDetectPlayerNotDrivingHook,"Cyberpunk2077.exe"+4B46B5)

assert(omniDetectPlayerNotDrivingHook,F3 44 0F 11 93 08 01 00 00)
alloc(detectPlayerNotDriving,$1000,omniDetectPlayerNotDrivingHook)
alloc(defaultPlayerVehicleSpeedX, 8)

registersymbol(omniDetectPlayerNotDrivingHook)

detectPlayerNotDriving:
    pushf
    push rax
    mov rax,playerLocationNormalized
    cmp [rax],rbx
    pop rax
    jne detectPlayerNotDrivingOriginalCode
    // If r10 is 0, then we may still be in the vehicle -- loading a save where we're already riding a vehicle
    // will cause this.
    cmp r10,0
    je detectPlayerNotDrivingOriginalCode
    // If we're at this point, we're not longer driving. We're on our feet!
    push rax
    mov rax,playerDriving
    mov [rax],0
    pop rax
    // Reset any changes made to the vehicle speed.
    push rax
    push rbx
    mov rax,defaultPlayerVehicleSpeedX
    mov rbx,[rax]
    mov rax,playerVehicleSpeedX
    mov [rax],rbx
    pop rbx
    pop rax
detectPlayerNotDrivingOriginalCode:
    popf
    movss [rbx+00000108],xmm10
    jmp detectPlayerNotDrivingReturn

omniDetectPlayerNotDrivingHook:
    jmp detectPlayerNotDriving
    nop 4
detectPlayerNotDrivingReturn:


defaultPlayerVehicleSpeedX:
    dd (float)1.0


[DISABLE]


// Cleanup of omniPlayerExperienceHook
omniPlayerExperienceHook:
    db 88 5E 63 48 85 C9

unregistersymbol(omniPlayerExperienceHook)
unregistersymbol(playerExperience)

dealloc(playerExperience)
dealloc(getPlayerExperience)


// Cleanup of omniPlayerMoneyHook
omniPlayerMoneyHook:
    db 48 8B 01 48 89 5C 24 40

unregistersymbol(omniPlayerMoneyHook)
unregistersymbol(playerMoney)

dealloc(playerMoney)
dealloc(getPlayerMoney)


// Cleanup of omniPlayerExperienceDataHook
omniPlayerExperienceDataHook:
    db 48 8B 3F 48 03 E8

unregistersymbol(omniPlayerExperienceDataHook)
unregistersymbol(playerExperienceData)

dealloc(playerExperienceData)
dealloc(getPlayerExperienceData)


// Cleanup of omniPlayerLocationHook
omniPlayerLocationHook:
    db 0F 10 81 10 02 00 00

unregistersymbol(omniPlayerLocationHook)
unregistersymbol(playerLocation)

dealloc(playerLocation)
dealloc(getPlayerLocation)


// Cleanup of omniPlayerLocationNormalizedHook
omniPlayerLocationNormalizedHook:
    db F3 0F 5C 83 08 01 00 00

unregistersymbol(omniPlayerLocationNormalizedHook)
unregistersymbol(playerLocationNormalized)

dealloc(playerLocationNormalized)
dealloc(getPlayerLocationNormalized)


// Cleanup of omniDetectPausedGame
omniDetectPausedGame:
    db 80 79 08 00 75 04

unregistersymbol(omniDetectPausedGame)
unregistersymbol(gamePaused)

dealloc(gamePaused)
dealloc(detectGamePaused)


// Cleanup of omniDetectUnpausedGame
omniDetectUnpausedGame:
    db 80 79 08 00 74 04

unregistersymbol(omniDetectUnpausedGame)

dealloc(detectGameUnpaused)


// Cleanup of omniPlayerMagazineBeforeFireHook
omniPlayerMagazineBeforeFireHook:
    db 0F B7 8E 50 03 00 00

unregistersymbol(omniPlayerMagazineBeforeFireHook)
unregistersymbol(playerMagazine)

dealloc(getPlayerMagazine)
dealloc(playerMagazine)


// Cleanup of omniPlayerMagazineAfterSwapHook
omniPlayerMagazineAfterSwapHook:
    db 41 89 3F 48 8B BE D0 02 00 00

unregistersymbol(omniPlayerMagazineAfterSwapHook)

dealloc(getPlayerMagazineAfterSwap)


// Cleanup of omnifyPlayerVitalsUpdateHook
omnifyPlayerVitalsUpdateHook:
    db F3 0F 11 82 90 01 00 00

unregistersymbol(omnifyPlayerVitalsUpdateHook)

dealloc(playerVitalsUpdate)


// Cleanup of omnifyPlayerLocationUpdateHook
omnifyPlayerLocationUpdateHook:
    db 41 0F 10 47 08

unregistersymbol(omnifyPlayerLocationUpdateHook)

dealloc(movementFramesToSkip)
dealloc(playerLocationUpdate)


// Cleanup of omniPlayerLocationVehicleHook
omniPlayerLocationVehicleHook:
    db 8B 02 89 01 8B 42 04

unregistersymbol(omniPlayerLocationVehicleHook)
unregistersymbol(playerLocationVehicle)

dealloc(playerLocationVehicle)
dealloc(positiveVehicleDistanceTolerance)
dealloc(negativeVehicleDistanceTolerance)
dealloc(getPlayerLocationVehicle)


// Cleanup of omnifyApocalypseHook
omnifyApocalypseHook:
    db F3 0F 58 89 90 01 00 00

unregistersymbol(omnifyApocalypseHook)
unregistersymbol(vehicleDamageX)

dealloc(initiateApocalypse)
dealloc(vehicleDamageX)


// Cleanup of omnifyPredatorHook
omnifyPredatorHook:
    db 0F 58 20 0F 28 D4

unregistersymbol(omnifyPredatorHook)
unregistersymbol(disablePredator)
unregistersymbol(verticalBoost)

dealloc(identityValue)
dealloc(disablePredator)
dealloc(verticalBoost)
dealloc(initiatePredator)


// Cleanup of omniPlayerHealthHook
omniPlayerHealthHook:
    db F3 0F 10 80 90 01 00 00

unregistersymbol(omniPlayerHealthHook)
unregistersymbol(playerHealth)
unregistersymbol(playerHealthValue)

dealloc(playerHealthValue)
dealloc(playerHealth)
dealloc(getPlayerHealth)


// Cleanup of omniPlayerStaminaHook
omniPlayerStaminaHook:
    db F3 0F 10 80 90 01 00 00

unregistersymbol(omniPlayerStaminaHook)
unregistersymbol(playerStamina)

dealloc(playerStamina)
dealloc(getPlayerStamina)


// Cleanup of omniPlayerHook
omniPlayerHook:
    db 4C 8B 0E 48 C7 C5 FF FF FF FF

unregistersymbol(omniPlayerHook)
unregistersymbol(player)
unregistersymbol(playerMaxStamina)
unregistersymbol(playerStaminaValue)

dealloc(player)
dealloc(playerMaxStamina)
dealloc(playerStaminaValue)
dealloc(getPlayer)


// Cleanup of omniDetectPlayerDriving
omniDetectPlayerDriving:
    db F3 0F 11 B1 08 01 00 00

unregistersymbol(omniDetectPlayerDriving)
unregistersymbol(playerDriving)

dealloc(playerDriving)
dealloc(detectPlayerDriving)


// Cleanup of omniDetectPlayerNotDrivingHook
omniDetectPlayerNotDrivingHook:
    db F3 44 0F 11 93 08 01 00 00

unregistersymbol(omniDetectPlayerNotDrivingHook)

dealloc(defaultPlayerVehicleSpeedX)
dealloc(detectPlayerNotDriving)


// Cleanup of omnifyPlayerVehicleSpeedHook
omnifyPlayerVehicleSpeedHook:
    db 8B 46 60 89 42 10

unregistersymbol(omnifyPlayerVehicleSpeedHook)
unregistersymbol(playerVehicleSpeedX)
unregistersymbol(playerVehicleVerticalSpeedX)

dealloc(playerVehicleSpeedX)
dealloc(playerVehicleVerticalSpeedX)
dealloc(setPlayerVehicleSpeed)


// Cleanup of omniPlayerAttackHook
omniPlayerAttackHook:
    db 48 8B 01 FF 90 20 01 00 00

unregistersymbol(omniPlayerAttackHook)
unregistersymbol(playerAttack)

dealloc(playerAttack)
dealloc(getPlayerAttack)