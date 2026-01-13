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
chrono_periods		DCD 0			; Compteur de périodes de 100ms écoulées

; =========== FONCTIONS EXPORTÉES ===========
	AREA    |.text|, CODE, READONLY
	EXPORT CHRONO_START
	EXPORT CHRONO_STOP
	EXPORT CHRONO_STOP_DISTANCE
	EXPORT CHRONO_GET_TIME_MS
	EXPORT MILLISECONDS_TO_DISTANCE
	EXPORT DELAY_MILLISECONDS

; ============================================================================
; CHRONO_START - Démarre le chronomètre
; ============================================================================
; Configure SysTick pour compter vers 0 depuis 0xFFFFFF (mode continu)
;
; Registres modifiés: R0, R6
; Retour: Aucun
; ============================================================================
CHRONO_START
	PUSH {R6}
	
	; Arrêter SysTick pendant configuration
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0
	STR R0, [R6]
	
	; Charger valeur maximale (compte sur 24 bits)
	LDR R6, =SYSTICK_LOAD
	LDR R0, =0xFFFFFF
	STR R0, [R6]
	
	; Réinitialiser le compteur à sa valeur maximale
	LDR R6, =SYSTICK_VAL
	MOV R0, #0
	STR R0, [R6]
	
	; Démarrer SysTick (Enable + CLK_SRC)
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0x05
	STR R0, [R6]
	
	; Sauvegarder le temps de départ
	LDR R6, =chrono_periods
	LDR R0, =SYSTICK_VAL
	LDR R0, [R0]
	STR R0, [R6]				; chrono_periods = valeur initiale
	
	POP {R6}
	BX LR

; ============================================================================
; CHRONO_STOP - Arrête le chronomètre et retourne le temps en millisecondes
; ============================================================================
; Calcule cycles écoulés = (valeur_départ - valeur_actuelle)
; Puis convertit en millisecondes
;
; Registres modifiés: R0, R1, R2, R6
; Retour: R0 = temps écoulé en millisecondes
; ============================================================================
CHRONO_STOP
	PUSH {R2, R6}
	
	; Lire la valeur actuelle
	LDR R6, =SYSTICK_VAL
	LDR R1, [R6]				; R1 = valeur actuelle (compte à rebours)
	
	; Arrêter SysTick
	LDR R6, =SYSTICK_CTRL
	MOV R0, #0
	STR R0, [R6]
	
	; Calculer cycles écoulés = valeur_départ - valeur_actuelle
	LDR R6, =chrono_periods
	LDR R0, [R6]				; R0 = valeur de départ
	SUB R2, R0, R1				; R2 = cycles écoulés
	
	; Convertir cycles → millisecondes
	; temps_ms = cycles / (16000000 / 1000) = cycles / 16000
	LDR R1, =16000
	UDIV R0, R2, R1
	
	POP {R2, R6}
	BX LR

; ============================================================================
; CHRONO_GET_TIME_MS - Retourne le temps écoulé sans arrêter le chrono
; ============================================================================
; Registres modifiés: R0, R1, R6
; Retour: R0 = temps écoulé en millisecondes
; ============================================================================
CHRONO_GET_TIME_MS
	PUSH {R6}
	
	; Lire COUNTFLAG
	LDR R6, =SYSTICK_CTRL
	LDR R0, [R6]
	TST R0, #(1 << 16)
	
	; Si COUNTFLAG=1, incrémenter
	BEQ CHRONO_GET_NO_INCREMENT
	
	LDR R6, =chrono_periods
	LDR R0, [R6]
	ADD R0, R0, #1
	STR R0, [R6]
	B CHRONO_GET_CONVERT

CHRONO_GET_NO_INCREMENT
	LDR R6, =chrono_periods
	LDR R0, [R6]

CHRONO_GET_CONVERT
	; Convertir périodes → millisecondes
	MOV R1, #PERIOD_MS
	MUL R0, R1, R0
	
	POP {R6}
	BX LR

; ============================================================================
; MILLISECONDS_TO_DISTANCE - Convertit millisecondes en distance (cm)
; ============================================================================
; FORMULE SIMPLE : Distance = (3 cm/s) × (temps_ms / 1000)
;
; Paramètres: R0 = temps en millisecondes
; Retour: R0 = distance en centimètres
; ============================================================================
MILLISECONDS_TO_DISTANCE
	PUSH {R2, LR}
	
	MOV R2, R0
	
	; Distance = (3 × temps_ms) / 1000
	MOV R0, #ROBOT_SPEED_CM_S
	MUL R0, R2, R0
	
	MOV R1, #1000
	UDIV R0, R0, R1
	
	POP {R2, PC}

; ============================================================================
; CHRONO_STOP_DISTANCE - Arrête le chrono et calcule la distance
; ============================================================================
; CHRONO_STOP → millisecondes → MILLISECONDS_TO_DISTANCE → centimètres
;
; Retour: R0 = distance en centimètres
; ============================================================================
CHRONO_STOP_DISTANCE
	PUSH {LR}
	
	BL CHRONO_STOP					; R0 = temps en ms
	BL MILLISECONDS_TO_DISTANCE		; R0 = distance en cm
	
	POP {PC}

; ============================================================================
; DELAY_MILLISECONDS - Génère un délai en millisecondes
; ============================================================================
; Paramètres: R0 = délai en millisecondes
; ============================================================================
DELAY_MILLISECONDS
	PUSH {R4, R5, LR}
	
	; Calculer nombre d'itérations de 100ms
	MOV R1, #PERIOD_MS
	UDIV R4, R0, R1
	
	CMP R4, #0
	MOVEQ R4, #1
	
	; Arrêter SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	; Charger valeur pour 100ms
	LDR R0, =SYSTICK_LOAD
	LDR R1, =PERIOD_RELOAD
	STR R1, [R0]
	
	; Réinitialiser compteur
	LDR R0, =SYSTICK_VAL
	MOV R1, #0
	STR R1, [R0]
	
	; Démarrer SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0x05
	STR R1, [R0]
	
DELAY_LOOP
	; Attendre COUNTFLAG=1
DELAY_WAIT_FLAG
	LDR R0, =SYSTICK_CTRL
	LDR R3, [R0]
	TST R3, #(1 << 16)
	BEQ DELAY_WAIT_FLAG
	
	; Décrémenter
	SUBS R4, R4, #1
	BNE DELAY_LOOP
	
	; Arrêter SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	POP {R4, R5, PC}

	END
