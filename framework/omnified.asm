//----------------------------------------------------------------------
// Omnified Framework Assembly Functions v. 0.5
// Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
// Copyright 2022 Bad Echo LLC
// 
// Bad Echo Technologies are licensed under the
// GNU Affero General Public License v3.0.
//
// See accompanying file LICENSE.md or a copy at:
// https://www.gnu.org/licenses/agpl-3.0.html
//----------------------------------------------------------------------

// Global memory.
alloc(zero,8)
alloc(epsilon,8)
alloc(damageThreshold,8)
alloc(yIsVertical,8)
alloc(negativeOne,8)
alloc(percentageDivisor,8)

registersymbol(epsilon)
registersymbol(zero)
registersymbol(damageThreshold)
registersymbol(yIsVertical)
registersymbol(negativeOne)
registersymbol(percentageDivisor)

zero:
    dd 0

epsilon:
    dd (float)0.001

damageThreshold:
    dd (float)3.9

yIsVertical:
    dd 1
  
negativeOne:
    dd (float)-1.0
  
percentageDivisor:
    dd (float)100.0

  
// Checks if the loaded address is a valid pointer.
// rcx: The address to check.
alloc(checkBadPointer,$1000)

registersymbol(checkBadPointer)

checkBadPointer:
    push rcx
    shr rcx,20
    cmp rcx,0x7FFF  
    pop rcx
    jg checkBadPointerExit
    sub rsp,10
    movdqu [rsp],xmm0
    sub rsp,10
    movdqu [rsp],xmm1
    sub rsp,10
    movdqu [rsp],xmm2
    sub rsp,10
    movdqu [rsp],xmm3
    sub rsp,10
    movdqu [rsp],xmm4
    sub rsp,10
    movdqu [rsp],xmm5
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp,rsp
    and spl,F0
    sub rsp,20
    mov edx,4
    call isBadReadPtr
    mov rcx,eax
    mov rsp,rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rbx
    pop rax
    movdqu xmm5,[rsp]
    add rsp,10
    movdqu xmm4,[rsp]
    add rsp,10
    movdqu xmm3,[rsp]
    add rsp,10
    movdqu xmm2,[rsp]
    add rsp,10
    movdqu xmm1,[rsp]
    add rsp,10
    movdqu xmm0,[rsp]
    add rsp,10
checkBadPointerExit:
    ret
  

// Mapping between thread ID's and their random number engine initialization
alloc(threadRandomInitMap,$FFFF)


// Random number generation function.
// After r12-r14 pushes:
// [rsp+20]: Upper bounds
// [rsp+28]: Lower bounds
// Return value is in EAX
alloc(generateRandomNumber,$1000)

registersymbol(generateRandomNumber)

generateRandomNumber:
    push r13
    push r14
    mov r13,[rsp+18]
    mov r14,[rsp+20]
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    // Load the current thread ID from the Thread Information Block.
    mov rbx,gs:[0x48]
    // Typically the thread ID will always be 2 bytes in length, but we'll specifically only grab a word's worth of it
    // just in case.
    movzx rax,bx  
    // Each entry in the thread random initialization map is only a single byte. A value of zero means it has not been 
    // initialized.  
    mov rcx,threadRandomInitMap
    add rcx,rax  
    cmp byte ptr [rcx],0
    jne getRandomNumber
initializeSeed:
    mov byte ptr [rcx],1
    call kernel32.GetTickCount
    // We don't want the same seed being generated for two different thread IDs, otherwise we'll see the unpleasant
    // unraveling of duplicate sequences, albeit in a staggered fashion most likely. We zero out the lower 16 bits of 
    // the returned tick count, which consists mainly of millisecond data (and can very easily end up not being different 
    // between two calls on two separate threads), and replace this data with the thread ID.
    shr rax,0x10
    shl rax,0x10
    or rax,rbx
    // This pretty much guarantees uniqueness on a per-thread level for a given game session.
    push eax
    call msvcrt.srand
    pop eax
getRandomNumber:
    call msvcrt.rand
    xor edx,edx
    mov ebx,r14
    mov ecx,r13
    cmp ecx,ebx
    cmovl ecx,ebx
    inc ecx
    sub ecx,ebx
    idiv ecx
    add edx,ebx
    mov eax,edx
    pop r11
    pop r10
    pop r9
    pop r8    
    pop rdx
    pop rcx
    pop rbx
    pop r14
    pop r13
    ret 10


// Mark and recall symbols.
alloc(teleport,8)
alloc(teleportX,8)
alloc(teleportY,8)
alloc(teleportZ,8)

registersymbol(teleport)
registersymbol(teleportX)
registersymbol(teleportY)
registersymbol(teleportZ)


[DISABLE]

// Cleanup of global memory
unregistersymbol(percentageDivisor)
unregistersymbol(epsilon)
unregistersymbol(yIsVertical)
unregistersymbol(negativeOne)
unregistersymbol(zero)

dealloc(zero)
dealloc(percentageDivisor)
dealloc(epsilon)
dealloc(damageThreshold)
dealloc(yIsVertical)
dealloc(negativeOne)


// Cleanup of checkBadPointer
unregistersymbol(checkBadPointer)

dealloc(checkBadPointer)


// Cleanup of thread ID mappings
dealloc(threadRandomInitMap)


// Cleanup of generateRandomNumber
unregistersymbol(generateRandomNumber)

dealloc(generateRandomNumber)


// Cleanup of Mark and Recall symbols
unregistersymbol(teleport)
unregistersymbol(teleportX)
unregistersymbol(teleportY)
unregistersymbol(teleportZ)

dealloc(teleport)
dealloc(teleportX)
dealloc(teleportY)
dealloc(teleportZ)