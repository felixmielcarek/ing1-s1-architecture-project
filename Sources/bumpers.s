	AREA    |.text|, CODE, READONLY

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO  EQU		0x400FE108 ; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTE_BASE		EQU		0x40024000 ; GPIO Port E (ABP) base : 0x4002.4000 (p291 datasheet de lm3s9b92.pdf)
	
; Digital enable register
; To use the pin as a digital input or output, the corresponding GPIODEN bit must be set.
GPIO_O_DEN  		EQU 	0x0000051C  ; GPIO Digital Enable (p437 datasheet de lm3s9B92.pdf)

; Direction register (0=input, 1=output)
GPIO_O_DIR			EQU		0x00000400	; GPIO Direction

; Pul_up
GPIO_I_PUR   		EQU 	0x00000510  ; GPIO Pull-Up (p432 datasheet de lm3s9B92.pdf)
	
BROCHE0             EQU     0x01		; Broche 0
BROCHE1             EQU     0x02        ; Broche 1	
BROCHE0_1           EQU     0x03        ; Broche 1 et 2
	
	EXPORT BUMPERS_INIT
	EXPORT READ_BUMPER1
	EXPORT READ_BUMPER2
	EXPORT READ_BUMPERS

; ============================================================================
; BUMPERS_INIT - Initialise les capteurs de collision (bumpers)
; ============================================================================
; Configure les broches PE0 et PE1 en entrées avec pull-up pour détecter
; les bumpers avant et arrière du robot.
;
; PRINCIPE DE FONCTIONNEMENT :
; - Les bumpers sont des interrupteurs normalement ouverts
; - Pull-up activé : quand bumper NON pressé, pin = 1 (tirée vers VDD)
; - Quand bumper pressé : pin = 0 (court-circuit à la masse GND)
;
; Configuration :
; - Port E, broches 0 et 1 en INPUT (par défaut)
; - Pull-up activé sur PE0 et PE1
; - Fonction digitale activée
; ============================================================================
BUMPERS_INIT
	PUSH {r6, LR}						; Sauvegarder registres préservés
	
	;branchement du port E
	ldr r6, = SYSCTL_PERIPH_GPIO  			;; RCGC2
	ldr r0, [r6]							;; Lire la valeur actuelle
	ORR r0, r0, #0x10 						;; Enable clock sur GPIO E 0x10 = ob010000
	str r0, [r6]
	
	nop
	nop
	nop
	
	; Configurer PE0 et PE1 en INPUT (bit à 0)
	ldr r6, = GPIO_PORTE_BASE+GPIO_O_DIR
	ldr r0, [r6]
	BIC r0, r0, #0x03						;; Clear bits 0 et 1 (INPUT)
	str r0, [r6]
	
	;setup bumpers pull-up
	ldr r6, = GPIO_PORTE_BASE+GPIO_I_PUR    ;; Pul_up
	ldr r0, = BROCHE0_1	
	str r0, [r6]
	
	; Enable Digital Function
	ldr r6, = GPIO_PORTE_BASE+GPIO_O_DEN    ;; Enable Digital Function 
	ldr r0, = BROCHE0_1	
	str r0, [r6]
	
	POP {r6, PC}						; Restaurer registres et retourner

; ============================================================================
; READ_BUMPER1 - Lit l'état du bumper 1 (PE0)
; ============================================================================
; Retour : r0 = 0x00 si pressé, 0x01 si non pressé
;          Flag Z = 1 si pressé (r0==0)
; ============================================================================
READ_BUMPER1
	PUSH {r9, LR}						; Sauvegarder registres préservés
	
	;lecture de l'etat du bumper1
	ldr r9, = GPIO_PORTE_BASE + (BROCHE0<<2)
	ldr r0, [r9]						; Lire dans r0 (valeur de retour)
	cmp r0, #0x00
	
	POP {r9, PC}						; Restaurer registres et retourner

; ============================================================================
; READ_BUMPER2 - Lit l'état du bumper 2 (PE1)
; ============================================================================
; Retour : r0 = 0x00 si pressé, 0x02 si non pressé
;          Flag Z = 1 si pressé (r0==0)
; ============================================================================
READ_BUMPER2
	PUSH {r8, LR}						; Sauvegarder registres préservés
	
	;lecture de l'etat du bumper2
	ldr r8, = GPIO_PORTE_BASE + (BROCHE1<<2)
	ldr r0, [r8]						; Lire dans r0 (valeur de retour)
	cmp r0, #0x00
	
	POP {r8, PC}						; Restaurer registres et retourner

; ============================================================================
; READ_BUMPERS - Lit l'état des deux bumpers en même temps
; ============================================================================
; Lit PE0 et PE1 simultanément
; 
; Valeurs possibles de r0 (retour) :
; - 0x03 (0b11) : Aucun bumper pressé (les deux à 1 grâce au pull-up)
; - 0x02 (0b10) : Bumper 1 pressé (PE0=0), bumper 2 non pressé (PE1=1)
; - 0x01 (0b01) : Bumper 1 non pressé (PE0=1), bumper 2 pressé (PE1=0)
; - 0x00 (0b00) : Les deux bumpers pressés
;
; Retour : r0 = valeur lue sur PE1:PE0 (CONVENTION ARM: retour dans r0)
; ============================================================================
READ_BUMPERS
	PUSH {r4, LR}							; Sauvegarder registres préservés
	ldr r4, = GPIO_PORTE_BASE + (BROCHE0_1<<2)
	ldr r0, [r4]							; Lire dans r0 (retour)
	POP {r4, PC}							; Restaurer et retourner

;fin du programme
	NOP
	NOP
	END