	;; Timer module - Chronomètre pour mesurer les distances parcourues
	;; Utilise SysTick (ARM Cortex-M3)
	;; Vitesse du robot : 3 cm/s
	
	AREA    |.text|, CODE, READONLY

; =========== CONSTANTES ===========
SYSTICK_CTRL		EQU 0xE000E010	; SysTick Control and Status
SYSTICK_LOAD		EQU 0xE000E014	; SysTick Reload Value
SYSTICK_VAL			EQU 0xE000E018	; SysTick Current Value

F_CPU_REAL			EQU 16000000	; 16 MHz
ROBOT_SPEED_CM_S	EQU 2			; 2 cm/s

; Période de mesure (100ms) - MÊME PRINCIPE pour CHRONO et DELAY
PERIOD_MS			EQU 100			; Période de 100ms
PERIOD_RELOAD		EQU 1600000-1	; Cycles pour 100ms à 16MHz

; =========== VARIABLES GLOBALES ===========
	AREA myTimerData, DATA, READWRITE
chrono_start_val	DCD 0			; Valeur de SysTick au démarrage
chrono_wraparounds	DCD 0			; Nombre de fois que SysTick a atteint 0

; =========== FONCTIONS EXPORTÉES ===========
	AREA    |.text|, CODE, READONLY
	EXPORT CHRONO_START
	EXPORT CHRONO_STOP_DISTANCE
	EXPORT DELAY_MILLISECONDS
	EXPORT SysTick_Handler

; ============================================================================
; SysTick_Handler - Gestionnaire d'interruption SysTick
; ============================================================================
; APPELÉ AUTOMATIQUEMENT quand SysTick atteint 0
; Incrémente le compteur de wraparounds pour permettre de mesurer
; des durées supérieures à 1 seconde
;
; Registres modifiés: R0, R1 (sauvegardés/restaurés automatiquement)
; ============================================================================
SysTick_Handler
	LDR R0, =chrono_wraparounds
	LDR R1, [R0]
	ADD R1, R1, #1
	STR R1, [R0]
	BX LR

; ============================================================================
; CHRONO_START - Démarre le chronomètre avec interruptions
; ============================================================================
; Configure SysTick avec interruption pour mesurer des durées longues
; Le compteur SysTick décrémente depuis 0xFFFFFF, et SysTick_Handler
; est appelé automatiquement à chaque fois qu'il atteint 0
;
; Registres modifiés: R0, R6
; ============================================================================
CHRONO_START
	PUSH {R6, LR}
	
	LDR R6, =chrono_wraparounds
	MOV R0, #0
	STR R0, [R6]
	
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0
	STR R0, [R6]
	
	LDR R6, =SYSTICK_LOAD
	LDR R0, =0xFFFFFF
	STR R0, [R6]
	
	LDR R6, =SYSTICK_VAL
	MOV R0, #0
	STR R0, [R6]
	
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0x07				; Enable + TICKINT + CLK_SRC
	STR R0, [R6]
	
	LDR R6, =chrono_start_val
	LDR R0, =SYSTICK_VAL
	LDR R0, [R0]
	STR R0, [R6]
	
	POP {R6, PC}

; ============================================================================
; CHRONO_STOP - Arrête le chronomètre et retourne le temps en ms
; ============================================================================
; Calcule cycles_total = (wraparounds × 0x1000000) + (départ - actuel)
; Puis convertit en millisecondes : temps_ms = cycles / 16000
;
; Retour: R0 = temps écoulé en millisecondes
; ============================================================================
CHRONO_STOP
	PUSH {R2, R3, R4, R6, LR}
	
	LDR R6, =SYSTICK_VAL
	LDR R1, [R6]
	
	LDR R6, =chrono_wraparounds
	LDR R3, [R6]
	
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0
	STR R0, [R6]
	
	LDR R6, =chrono_start_val
	LDR R0, [R6]
	SUB R2, R0, R1
	
	LDR R4, =0x1000000
	MUL R3, R4, R3
	ADD R2, R2, R3
	
	LDR R1, =16000
	UDIV R0, R2, R1
	
	POP {R2, R3, R4, R6, PC}

; ============================================================================
; MILLISECONDS_TO_DISTANCE - Convertit millisecondes en distance (cm)
; ============================================================================
; Distance = (vitesse × temps) / 1000
; Paramètres: R0 = temps en millisecondes
; Retour: R0 = distance en centimètres
; ============================================================================
MILLISECONDS_TO_DISTANCE
	PUSH {R2, LR}
	MOV R2, R0
	MOV R0, #ROBOT_SPEED_CM_S
	MUL R0, R2, R0
	MOV R1, #1000
	UDIV R0, R0, R1
	POP {R2, PC}

; ============================================================================
; CHRONO_STOP_DISTANCE - Arrête le chrono et calcule la distance
; ============================================================================
CHRONO_STOP_DISTANCE
	PUSH {LR}
	BL CHRONO_STOP
	BL MILLISECONDS_TO_DISTANCE
	POP {PC}

; ============================================================================
; DELAY_MILLISECONDS - Génère un délai en millisecondes
; ============================================================================
; Paramètres: R0 = délai en millisecondes
; ============================================================================
DELAY_MILLISECONDS
	PUSH {R4, R5, LR}
	
	MOV R1, #PERIOD_MS
	UDIV R4, R0, R1
	CMP R4, #0
	MOVEQ R4, #1
	
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	LDR R0, =SYSTICK_LOAD
	LDR R1, =PERIOD_RELOAD
	STR R1, [R0]
	
	LDR R0, =SYSTICK_VAL
	MOV R1, #0
	STR R1, [R0]
	
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0x05
	STR R1, [R0]
	
DELAY_LOOP
DELAY_WAIT_FLAG
	LDR R0, =SYSTICK_CTRL
	LDR R3, [R0]
	TST R3, #(1 << 16)
	BEQ DELAY_WAIT_FLAG
	
	SUBS R4, R4, #1
	BNE DELAY_LOOP
	
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	POP {R4, R5, PC}

	END
