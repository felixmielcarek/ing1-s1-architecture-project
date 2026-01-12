	;; Timer module - Chronomètre pour mesurer les distances parcourues
	;; Utilise SysTick (ARM Cortex-M3)
	;; Vitesse du robot : 3 cm/s
	
	AREA    |.text|, CODE, READONLY

; =========== CONSTANTES ===========
SYSTICK_CTRL		EQU 0xE000E010	; SysTick Control and Status
SYSTICK_LOAD		EQU 0xE000E014	; SysTick Reload Value
SYSTICK_VAL			EQU 0xE000E018	; SysTick Current Value

F_CPU_REAL			EQU 16000000	; 16 MHz
ROBOT_SPEED_CM_S	EQU 3			; 3 cm/s

; =========== FONCTIONS EXPORTÉES ===========
	EXPORT CHRONO_START
	EXPORT CHRONO_STOP_DISTANCE
	EXPORT CHRONO_GET_CYCLES

; ============================================================================
; CHRONO_START - Démarre le chronomètre
; ============================================================================
; Configure SysTick en mode compte à rebours pour mesurer le temps écoulé.
;
; Registres modifiés: R0, R1
; Retour: Aucun
; ============================================================================
CHRONO_START
	; Arrêter SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0x00
	STR R1, [R0]
	
	; Charger valeur maximale (24-bit = 0xFFFFFF)
	LDR R0, =SYSTICK_LOAD
	LDR R1, =0x00FFFFFF
	STR R1, [R0]
	
	; Réinitialiser le compteur à 0
	LDR R0, =SYSTICK_VAL
	MOV R1, #0x00
	STR R1, [R0]
	
	; Démarrer SysTick (enable + horloge processeur)
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0x05			; Enable + CLK_SRC
	STR R1, [R0]
	
	BX LR

; ============================================================================
; CHRONO_STOP_DISTANCE - Arrête le chrono et calcule la distance parcourue
; ============================================================================
; Calcule la distance parcourue en centimètres à partir du temps mesuré.
;
; FORMULE:
; Distance (cm) = Vitesse (cm/s) × Temps (s)
; Distance = 3 cm/s × (cycles_écoulés / 16000000 cycles/s)
; Distance = (3 × cycles_écoulés) / 16000000
;
; Pour plus de précision:
; Distance_mm = (30 × cycles_écoulés) / 16000000  (en mm)
; Distance_cm = Distance_mm / 10
;
; Registres modifiés: R0, R1, R2, R3
; Retour: R0 = distance parcourue en centimètres (arrondi)
; ============================================================================
CHRONO_STOP_DISTANCE
	; Lire la valeur actuelle du SysTick
	LDR R0, =SYSTICK_VAL
	LDR R1, [R0]
	
	; Arrêter SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R2, #0
	STR R2, [R0]
	
	; Calculer les cycles écoulés = valeur_max - valeur_actuelle
	LDR R2, =0x00FFFFFF
	SUB R3, R2, R1			; R3 = cycles écoulés depuis CHRONO_START
	
	; Calculer la distance en millimètres pour plus de précision
	; Distance_mm = (30 × cycles) / 16000000
	; (30 = 3 cm/s × 10 mm/cm)
	MOV R0, #30
	MUL R0, R3, R0			; R0 = 30 × cycles
	
	; Diviser par la fréquence CPU pour obtenir des millimètres
	LDR R1, =F_CPU_REAL
	UDIV R0, R0, R1			; R0 = distance en millimètres
	
	; Convertir en centimètres (diviser par 10)
	MOV R1, #10
	UDIV R0, R0, R1			; R0 = distance en centimètres
	
	BX LR

; ============================================================================
; CHRONO_GET_CYCLES - Retourne les cycles écoulés sans arrêter le chrono
; ============================================================================
; Fonction utilitaire pour lire le temps écoulé sans arrêter le chronomètre.
;
; Registres modifiés: R0, R1, R2
; Retour: R0 = nombre de cycles écoulés
; ============================================================================
CHRONO_GET_CYCLES
	; Lire la valeur actuelle du SysTick
	LDR R0, =SYSTICK_VAL
	LDR R1, [R0]
	
	; Calculer cycles = max - actuel
	LDR R2, =0x00FFFFFF
	SUB R0, R2, R1			; R0 = cycles écoulés
	
	BX LR

	END
