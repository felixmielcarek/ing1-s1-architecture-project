	AREA    |.text|, CODE, READONLY

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO  EQU		0x400FE108 ; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTE_BASE		EQU		0x40024000 ; GPIO Port E (ABP) base : 0x4002.4000 (p291 datasheet de lm3s9b92.pdf)
	
; Digital enable register
; To use the pin as a digital input or output, the corresponding GPIODEN bit must be set.
GPIO_O_DEN  		EQU 	0x0000051C  ; GPIO Digital Enable (p437 datasheet de lm3s9B92.pdf)

; Pul_up
GPIO_I_PUR   		EQU 	0x00000510  ; GPIO Pull-Up (p432 datasheet de lm3s9B92.pdf)
	
BROCHE0             EQU     0x01		; Broche 0
BROCHE1             EQU     0x02        ; Broche 1	
BROCHE0_1           EQU     0x03        ; Broche 1 et 2
	
	EXPORT BUMPERS_INIT
	EXPORT READ_BUMPER1
	EXPORT READ_BUMPER2
	EXPORT READ_BUMPERS

BUMPERS_INIT
	;branchement du port E
	ldr r6, = SYSCTL_PERIPH_GPIO  			;; RCGC2
	mov r0, #0x10 							;; Enable clock sur GPIO E 0x10 = ob010000
	str r0, [r6]
	
	nop
	nop
	nop
	
	;setup bumpers
	ldr r6, = GPIO_PORTE_BASE+GPIO_I_PUR    ;; Pul_up
	ldr r0, = BROCHE0_1	
	str r0, [r6]
	
	ldr r6, = GPIO_PORTE_BASE+GPIO_O_DEN    ;; Enable Digital Function 
	ldr r0, = BROCHE0_1	
	str r0, [r6]
	
	ldr r9, = GPIO_PORTE_BASE + (BROCHE0<<2)
	ldr r8, = GPIO_PORTE_BASE + (BROCHE1<<2)
	
	BX LR

READ_BUMPER1
	;lecture de l'etat du bumper1
	ldr r9, = GPIO_PORTE_BASE + (BROCHE0<<2)
	ldr r5, [r9]
	cmp r5,#0x00
	BX LR

READ_BUMPER2
	;lecture de l'etat du bumper2
	ldr r8, = GPIO_PORTE_BASE + (BROCHE1<<2)
	ldr r5, [r8]
	cmp r5,#0x00
	BX LR

READ_BUMPERS
	;lecture des deux ports en meme temps
	ldr r8, = GPIO_PORTE_BASE + (BROCHE0_1<<2)
	ldr r5, [r8]
	cmp r5,#0x00
	BX LR

;fin du programme
	NOP
	NOP
	END