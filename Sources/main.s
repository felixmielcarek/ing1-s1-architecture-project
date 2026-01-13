	
	;; RK - Evalbot (Cortex M3 de Texas Instrument)
   	
	AREA    |.text|, CODE, READONLY
 
; CONSTANTS DECLARATION
MAX_ROTATIONS	EQU		4		; Nombre maximum de rotations avant arrêt

	ENTRY
	EXPORT	__main

	IMPORT MOTEUR_INIT
	
	IMPORT MOTEUR_GAUCHE_ON
	IMPORT MOTEUR_DROIT_ON
	
	IMPORT MOTEUR_GAUCHE_OFF
	IMPORT MOTEUR_DROIT_OFF
		

	IMPORT MOTEUR_DROIT_AVANT
	IMPORT MOTEUR_GAUCHE_AVANT

	IMPORT ROTATION_90_GAUCHE
	IMPORT ROTATION_90_DROITE
	
	IMPORT BUMPERS_INIT
	IMPORT READ_BUMPERS
	
	IMPORT SWITCHES_INIT
	IMPORT WAIT_SWITCH_PRESS
	
	IMPORT CHRONO_START
	IMPORT CHRONO_STOP_DISTANCE
	IMPORT DELAY_MILLISECONDS
	
	IMPORT LEDS_INIT
	IMPORT LED_GAUCHE_BLINK_N_TIMES

; ============================================================================
; ZONE DE DONNÉES - Stockage des distances parcourues
; ============================================================================
	AREA myData, DATA, READWRITE
	
; Tableau pour stocker les 4 distances (en cm) entre chaque rotation
; distances[0] = distance avant 1ère rotation
; distances[1] = distance avant 2ème rotation
; distances[2] = distance avant 3ème rotation
; distances[3] = distance avant 4ème rotation
distances	SPACE 16		; 4 distances × 4 bytes = 16 bytes

	AREA    |.text|, CODE, READONLY

__main
	; ========================================================================
	; INITIALISATION
	; ========================================================================
	BL MOTEUR_INIT
	BL BUMPERS_INIT
	BL SWITCHES_INIT
	BL LEDS_INIT
	
	
	; ========================================================================
	; ATTENTE DU CHOIX DE DIRECTION (SW1=gauche, SW2=droite)
	; ========================================================================
	BL WAIT_SWITCH_PRESS
	MOV r4, r0
	
	; ========================================================================
	; INITIALISATION DU COMPTEUR DE ROTATIONS
	; ========================================================================
	MOV r7, #0

loop
	; ========================================================================
	; AVANCER EN LIGNE DROITE
	; ========================================================================
	BL CHRONO_START
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; ========================================================================
	; VÉRIFICATION CONTINUE DES BUMPERS
	; ========================================================================
check_bumpers
	BL READ_BUMPERS
	CMP r0, #0x03
	BEQ check_bumpers
	
	; ========================================================================
	; GESTION DE LA COLLISION
	; ========================================================================
	BL CHRONO_STOP_DISTANCE
	LDR r8, =distances
	STR r0, [r8, r7, LSL #2]
	
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	CMP r4, #1
	BEQ rotate_left
	
rotate_right
	BL ROTATION_90_DROITE
	B continue_loop
	
rotate_left
	BL ROTATION_90_GAUCHE
	
continue_loop
	; ========================================================================
	; INCRÉMENTER LE COMPTEUR DE ROTATIONS
	; ========================================================================
	ADD r7, r7, #1
	CMP r7, #MAX_ROTATIONS
	BGE stop_robot
	B loop

; ============================================================================
; ARRÊT DU ROBOT ET AFFICHAGE DU RÉSULTAT
; ============================================================================
stop_robot
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Calculer distance[1] × distance[2]
	LDR r8, =distances
	LDR r0, [r8, #4]
	LDR r1, [r8, #8]
	MUL r5, r1, r0
	
	; Affichage : DIZAINES puis UNITÉS
	MOV r0, r5
	MOV r1, #10
	UDIV r6, r0, r1
	
	MOV r0, r6
	BL LED_GAUCHE_BLINK_N_TIMES
	
	LDR r0, =2000
	BL DELAY_MILLISECONDS
	
	MOV r0, #10
	MUL r1, r6, r0
	SUB r7, r5, r1
	
	MOV r0, r7
	BL LED_GAUCHE_BLINK_N_TIMES
	
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Boucle infinie : le robot reste arrêté
end_loop
	B end_loop

    END 