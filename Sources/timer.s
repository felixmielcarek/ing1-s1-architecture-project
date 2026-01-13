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
	EXPORT CHRONO_STOP
	EXPORT CHRONO_STOP_DISTANCE
	EXPORT CHRONO_GET_CYCLES
	EXPORT CYCLES_TO_DISTANCE
	EXPORT DELAY_MILLISECONDS

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
; CHRONO_STOP - Arrête le chronomètre et retourne le temps écoulé
; ============================================================================
; Arrête SysTick et retourne le nombre de cycles écoulés depuis CHRONO_START.
; Cette fonction sépare la mesure du temps du calcul de distance.
;
; Avantages :
; - Réutilisable pour d'autres calculs (vitesse, accélération, etc.)
; - Permet de stocker le temps avant conversion
; - Plus flexible que CHRONO_STOP_DISTANCE
;
; Registres modifiés: R0, R1, R2
; Retour: R0 = nombre de cycles écoulés depuis CHRONO_START
; ============================================================================
CHRONO_STOP
	; Lire la valeur actuelle du SysTick
	LDR R0, =SYSTICK_VAL
	LDR R1, [R0]
	
	; Arrêter SysTick
	LDR R0, =SYSTICK_CTRL
	MOV R2, #0
	STR R2, [R0]
	
	; Calculer les cycles écoulés = valeur_max - valeur_actuelle
	LDR R2, =0x00FFFFFF
	SUB R0, R2, R1			; R0 = cycles écoulés
	
	BX LR

; ============================================================================
; CYCLES_TO_DISTANCE - Convertit des cycles CPU en distance (cm)
; ============================================================================
; Convertit un nombre de cycles CPU en distance parcourue en centimètres,
; en fonction de la vitesse du robot (3 cm/s) et de la fréquence CPU (16 MHz).
;
; FORMULE:
; Distance (cm) = Vitesse (cm/s) × Temps (s)
; Distance = 3 cm/s × (cycles / 16000000 cycles/s)
; Distance = (3 × cycles) / 16000000
;
; Méthode avec précision en millimètres :
; Distance_mm = (30 × cycles) / 16000000
; Distance_cm = Distance_mm / 10
;
; Paramètres:
; R0 = nombre de cycles écoulés
;
; Registres modifiés: R0, R1
; Retour: R0 = distance parcourue en centimètres (arrondi)
; ============================================================================
CYCLES_TO_DISTANCE
	PUSH {R2, LR}
	
	MOV R2, R0				; Sauvegarder cycles dans R2
	
	; Calculer la distance en millimètres pour plus de précision
	; Distance_mm = (30 × cycles) / 16000000
	; (30 = 3 cm/s × 10 mm/cm)
	MOV R0, #30
	MUL R0, R2, R0			; R0 = 30 × cycles
	
	; Diviser par la fréquence CPU pour obtenir des millimètres
	LDR R1, =F_CPU_REAL
	UDIV R0, R0, R1			; R0 = distance en millimètres
	
	; Convertir en centimètres (diviser par 10)
	MOV R1, #10
	UDIV R0, R0, R1			; R0 = distance en centimètres
	
	POP {R2, PC}

; ============================================================================
; CHRONO_STOP_DISTANCE - Arrête le chrono et calcule la distance parcourue
; ============================================================================
; Fonction de compatibilité qui combine CHRONO_STOP + CYCLES_TO_DISTANCE.
; Arrête le chronomètre et calcule directement la distance en centimètres.
;
; Cette fonction est conservée pour la compatibilité avec le code existant.
; Pour plus de flexibilité, utilisez CHRONO_STOP puis CYCLES_TO_DISTANCE.
;
; Registres modifiés: R0, R1, R2, R3
; Retour: R0 = distance parcourue en centimètres (arrondi)
; ============================================================================
CHRONO_STOP_DISTANCE
	PUSH {LR}
	
	; Arrêter le chrono et obtenir les cycles
	BL CHRONO_STOP			; R0 = cycles écoulés
	
	; Convertir en distance
	BL CYCLES_TO_DISTANCE	; R0 = distance en cm
	
	POP {PC}

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

; ============================================================================
; DELAY_MILLISECONDS - Génère un délai en millisecondes
; ============================================================================
; Utilise SysTick pour créer un délai précis basé sur l'horloge CPU.
; ATTENTION : Cette fonction reconfigure SysTick. Ne pas appeler pendant
; qu'un chronomètre est actif (entre CHRONO_START et CHRONO_STOP).
;
; Principe :
; - Configure SysTick pour compter 0.1 seconde (100 ms)
; - Répète N fois selon le délai demandé
; - Utilise le flag COUNTFLAG pour détecter la fin de chaque période
;
; Paramètres:
; R0 = délai en millisecondes (multiple de 100 recommandé pour précision)
;
; Registres modifiés: R0, R1, R2, R3
; Retour: Aucun
; ============================================================================
DELAY_MILLISECONDS
	PUSH {R4, R5, LR}
	
	; Calculer le nombre d'itérations de 100ms
	; Nombre d'itérations = délai_ms / 100
	MOV R1, #100
	UDIV R4, R0, R1			; R4 = nombre d'itérations de 100ms
	
	; Si R4 = 0, délai trop court, faire au moins 1 itération
	CMP R4, #0
	MOVEQ R4, #1
	
	; ===== Configuration SysTick pour 0.1 seconde =====
	; Arrêter SysTick pendant configuration
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	; Charger valeur pour 0.1 seconde
	; F_CPU = 16 MHz, 0.1s = 16000000 / 10 = 1600000 cycles
	LDR R0, =SYSTICK_LOAD
	LDR R1, =1600000-1
	STR R1, [R0]
	
	; Réinitialiser le compteur
	LDR R0, =SYSTICK_VAL
	MOV R1, #0
	STR R1, [R0]
	
	; Démarrer SysTick (Enable + CLK_SRC, pas d'interruption)
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0x05			; Bit 0=ENABLE, Bit 2=CLKSOURCE
	STR R1, [R0]
	
	; ===== Boucle d'attente =====
DELAY_LOOP
	; Attendre que COUNTFLAG soit mis à 1 (bit 16 de CTRL)
DELAY_WAIT_FLAG
	LDR R0, =SYSTICK_CTRL
	LDR R3, [R0]
	TST R3, #(1 << 16)		; Tester bit 16 (COUNTFLAG)
	BEQ DELAY_WAIT_FLAG		; Si = 0, continuer à attendre
	
	; COUNTFLAG = 1, une période de 100ms s'est écoulée
	; Décrémenter le compteur d'itérations
	SUBS R4, R4, #1
	BNE DELAY_LOOP			; Si R4 != 0, continuer
	
	; ===== Arrêter SysTick =====
	LDR R0, =SYSTICK_CTRL
	MOV R1, #0
	STR R1, [R0]
	
	POP {R4, R5, PC}

	END
