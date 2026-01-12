	AREA    |.text|, CODE, READONLY

; ============================================================================
; Configuration des switches (boutons poussoirs) du Stellaris EvalBot
; ============================================================================
; Le robot a 2 boutons sur le Port D :
; - Switch 1 (SW1) : PD6 (broche 6)
; - Switch 2 (SW2) : PD7 (broche 7)
;
; Les switches sont câblés avec pull-up :
; - Switch NON pressé : pin = 1 (pull-up tire vers VDD)
; - Switch pressé : pin = 0 (court-circuit à la masse)
; ============================================================================

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO  EQU		0x400FE108 ; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; GPIO Port D base address
GPIO_PORTD_BASE		EQU		0x40007000 ; GPIO Port D (APB) base : 0x4000.7000 (p291)
	
; Digital enable register
GPIO_O_DEN  		EQU 	0x0000051C  ; GPIO Digital Enable (p437)

; Pull-up register
GPIO_I_PUR   		EQU 	0x00000510  ; GPIO Pull-Up (p432)

; Direction register (0=input, 1=output)
GPIO_O_DIR			EQU		0x00000400	; GPIO Direction (p417)
	
; Masques pour les switches
SWITCH1             EQU     0x40		; Broche 6 (PD6) = 0b01000000
SWITCH2             EQU     0x80        ; Broche 7 (PD7) = 0b10000000
SWITCHES_BOTH       EQU     0xC0        ; Broches 6 et 7 = 0b11000000
	
	EXPORT SWITCHES_INIT
	EXPORT READ_SWITCH1
	EXPORT READ_SWITCH2
	EXPORT WAIT_SWITCH_PRESS
	EXPORT GET_ROTATION_DIRECTION

; ============================================================================
; SWITCHES_INIT - Initialise les boutons poussoirs
; ============================================================================
; Configure les broches PD6 et PD7 en entrées avec pull-up pour lire
; les états des deux switches du robot.
;
; Configuration :
; - Port D, broches 6 et 7 en INPUT (par défaut)
; - Pull-up activé sur PD6 et PD7
; - Fonction digitale activée
;
; NOTE : Le Port D est déjà activé par MOTEUR_INIT, mais on s'assure
; que l'horloge est bien active (utilisation de ORR, pas MOV)
; ============================================================================
SWITCHES_INIT	
	PUSH {r6, LR}						; Sauvegarder registres préservés
	
	; Activer l'horloge du port D (bit 3 de RCGC2)
	; NOTE: Déjà fait dans MOTEUR_INIT, mais on s'assure avec ORR
	ldr r6, = SYSCTL_PERIPH_GPIO  			; RCGC2
	ldr r0, [r6]							; Lire la valeur actuelle
	ORR r0, r0, #0x08 						; Enable clock sur GPIO D (bit 3)
	str r0, [r6]
	
	nop
	nop
	nop
	
	; Activer les pull-ups sur PD6 et PD7
	ldr r6, = GPIO_PORTD_BASE+GPIO_I_PUR
	ldr r0, = SWITCHES_BOTH	
	str r0, [r6]
	
	; Activer la fonction digitale sur PD6 et PD7
	ldr r6, = GPIO_PORTD_BASE+GPIO_O_DEN
	ldr r0, = SWITCHES_BOTH
	str r0, [r6]
	
	POP {r6, PC}						; Restaurer registres et retourner

; ============================================================================
; READ_SWITCH1 - Lit l'état du switch 1 (PD6)
; ============================================================================
; Retour : r0 = 0x00 si pressé, 0x40 si non pressé
;          Flag Z = 1 si pressé (r0==0)
; ============================================================================
READ_SWITCH1
	PUSH {r6, LR}						; Sauvegarder registres préservés
	
	ldr r6, = GPIO_PORTD_BASE + (SWITCH1<<2)
	ldr r0, [r6]						; Lire l'état dans r0 (valeur de retour)
	cmp r0, #0x00
	
	POP {r6, PC}						; Restaurer registres et retourner

; ============================================================================
; READ_SWITCH2 - Lit l'état du switch 2 (PD7)
; ============================================================================
; Retour : r0 = 0x00 si pressé, 0x80 si non pressé
;          Flag Z = 1 si pressé (r0==0)
; ============================================================================
READ_SWITCH2
	PUSH {r6, LR}						; Sauvegarder registres préservés
	
	ldr r6, = GPIO_PORTD_BASE + (SWITCH2<<2)
	ldr r0, [r6]						; Lire l'état dans r0 (valeur de retour)
	cmp r0, #0x00
	
	POP {r6, PC}						; Restaurer registres et retourner

; ============================================================================
; WAIT_SWITCH_PRESS - Attend qu'un switch soit pressé
; ============================================================================
; Boucle jusqu'à ce qu'un des deux switches soit pressé.
; Cette fonction bloque l'exécution jusqu'à ce qu'un switch soit activé.
;
; Retour : r0 = 1 si Switch1 pressé (rotation gauche)
;          r0 = 2 si Switch2 pressé (rotation droite)
; ============================================================================
WAIT_SWITCH_PRESS
	PUSH {r6, r10, LR}				; Sauvegarder registres préservés
	
WAIT_LOOP
	; Lire Switch 1 (PD6)
	ldr r6, = GPIO_PORTD_BASE + (SWITCH1<<2)
	ldr r10, [r6]
	CMP r10, #0x00
	BEQ SWITCH1_PRESSED		; Si = 0x00, switch 1 pressé
	
	; Lire Switch 2 (PD7)
	ldr r6, = GPIO_PORTD_BASE + (SWITCH2<<2)
	ldr r10, [r6]
	CMP r10, #0x00
	BEQ SWITCH2_PRESSED		; Si = 0x00, switch 2 pressé
	
	; Aucun switch pressé, reboucler
	B WAIT_LOOP

SWITCH1_PRESSED
	MOV r0, #1				; r0 = 1 pour rotation gauche (convention AAPCS)
	POP {r6, r10, PC}				; Restaurer registres et retourner

SWITCH2_PRESSED
	MOV r0, #2				; r0 = 2 pour rotation droite (convention AAPCS)
	POP {r6, r10, PC}				; Restaurer registres et retourner

; ============================================================================
; GET_ROTATION_DIRECTION - Retourne le sens de rotation mémorisé
; ============================================================================
; Cette fonction retourne simplement la valeur stockée dans r4 qui indique
; quel switch a été pressé au démarrage.
;
; Entrée : r4 = direction (1=gauche, 2=droite)
; Retour : r0 = direction (1=gauche, 2=droite)
; ============================================================================
GET_ROTATION_DIRECTION
	MOV r0, r4				; Copier la direction vers r0 (convention ARM AAPCS)
	BX LR

	NOP
	NOP
	END