	;; LEDs module - Contrôle des LEDs du robot
	;; LED gauche (PF5) et LED droite (PF4) - Stellaris EvalBot LM3S1968
	
	AREA    |.text|, CODE, READONLY

; =========== CONSTANTES ===========
; Port F (LEDs)
PORTF_BASE			EQU 0x40025000
GPIODATA_F			EQU PORTF_BASE + 0x000
GPIODIR_F			EQU PORTF_BASE + 0x400
GPIODR2R_F			EQU PORTF_BASE + 0x500
GPIODEN_F			EQU PORTF_BASE + 0x51C

SYSCTL_RCGC2		EQU 0x400FE108

; Pins des LEDs (PF4 et PF5 comme dans l'exemple du EvalBot)
LED_DROITE			EQU 0x10		; PF4 (bit 4)
LED_GAUCHE			EQU 0x20		; PF5 (bit 5)
BROCHES_LEDS		EQU 0x30		; PF4 et PF5

; Délai pour le clignotement (approximatif)
DELAY_COUNT			EQU 1600000		; ~1 seconde à 16 MHz

; =========== FONCTIONS EXPORTÉES ===========
	EXPORT LEDS_INIT
	EXPORT LED_GAUCHE_BLINK_N_TIMES

; ============================================================================
; LEDS_INIT - Initialise les LEDs
; ============================================================================
; Configure PF0 (LED droite) et PF1 (LED gauche) en sortie
;
; Registres modifiés: R0, R1, R2
; Retour: Aucun
; ============================================================================
LEDS_INIT
	; Activer l'horloge du Port F
	LDR R0, =SYSCTL_RCGC2
	LDR R1, [R0]				; Lire la valeur actuelle
	ORR R1, R1, #0x20			; Bit 5 = Port F
	STR R1, [R0]
	
	; Délai stabilisation (3 cycles minimum)
	NOP
	NOP
	NOP
	
	; Configurer PF4 et PF5 en sortie
	LDR R0, =GPIODIR_F
	LDR R1, [R0]				; Lire la valeur actuelle
	ORR R1, R1, #BROCHES_LEDS	; Activer bits 4 et 5 en sortie
	STR R1, [R0]
	
	; Activer les fonctions digitales
	LDR R0, =GPIODEN_F
	LDR R1, [R0]				; Lire la valeur actuelle
	ORR R1, R1, #BROCHES_LEDS	; Activer digital sur PF4 et PF5
	STR R1, [R0]
	
	; Configurer l'intensité de sortie (2mA)
	LDR R0, =GPIODR2R_F
	LDR R1, [R0]				; Lire la valeur actuelle
	ORR R1, R1, #BROCHES_LEDS	; Activer 2mA sur PF4 et PF5
	STR R1, [R0]
	
	; Éteindre les deux LEDs au démarrage
	LDR R0, =(GPIODATA_F + (BROCHES_LEDS << 2))
	MOV R1, #0
	STR R1, [R0]
	
	BX LR

; ============================================================================
; LED_GAUCHE_BLINK_N_TIMES - Fait clignoter la LED gauche N fois
; ============================================================================
; Fait clignoter la LED gauche un nombre de fois spécifié
; Chaque clignotement : ON pendant 0.2s, OFF pendant 0.2s
;
; Paramètres:
; R0 = nombre de clignotements
;
; Registres modifiés: R0, R1, R2, R3, R4
; Retour: Aucun
; ============================================================================
LED_GAUCHE_BLINK_N_TIMES
	PUSH {R4, LR}				; Sauvegarder r4 (préservé) et LR (appels de fonction)
	MOV R4, R0					; R4 = compteur de clignotements
	
	; Si R0 = 0, ne rien faire
	CMP R4, #0
	BEQ end_blink
	
blink_loop
	; Allumer la LED gauche
	LDR R0, =(GPIODATA_F + (LED_GAUCHE << 2))
	MOV R1, #LED_GAUCHE
	STR R1, [R0]
	
	; Délai ON
	BL LED_DELAY
	
	; Éteindre la LED gauche
	LDR R0, =(GPIODATA_F + (LED_GAUCHE << 2))
	MOV R1, #0
	STR R1, [R0]
	
	; Délai OFF
	BL LED_DELAY
	
	; Décrémenter le compteur
	SUBS R4, R4, #1
	BNE blink_loop
	
end_blink
	POP {R4, PC}

; ============================================================================
; LED_DELAY - Délai pour le clignotement
; ============================================================================
; Génère un délai d'environ 0.2 seconde
;
; Registres modifiés: R5
; Retour: Aucun
; ============================================================================
LED_DELAY
	PUSH {R5, LR}				; Sauvegarder r5 (préservé)
	LDR R5, =DELAY_COUNT
delay_loop
	SUBS R5, R5, #1
	BNE delay_loop
	POP {R5, PC}

	END
