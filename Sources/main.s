	
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
	
	; Test LED : clignoter 3 fois au démarrage
	MOV r0, #3
	BL LED_GAUCHE_BLINK_N_TIMES
	
	; ========================================================================
	; ATTENTE DU CHOIX DE DIRECTION
	; ========================================================================
	; SW1 = rotation gauche, SW2 = rotation droite
	; Retour dans r0: 1=gauche, 2=droite
	BL WAIT_SWITCH_PRESS
	MOV r4, r0					; Stocker la direction dans r4 (registre global)
	
	; ========================================================================
	; INITIALISATION DU COMPTEUR DE ROTATIONS
	; ========================================================================
	; r7 = compteur de rotations (commence à 0)
	MOV r7, #0

loop	
	; ========================================================================
	; 1. AVANCER EN LIGNE DROITE
	; ========================================================================
	BL CHRONO_START
	
	; Configurer la direction AVANT d'activer les moteurs
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; ========================================================================
	; 2. VÉRIFICATION CONTINUE DES BUMPERS
	; ========================================================================
	; r0 = 0x03 si bumpers non pressés, 0x00 si pressés
check_bumpers
	BL READ_BUMPERS
	CMP r0, #0x03
	BEQ check_bumpers
	
	; ========================================================================
	; 3. GESTION DE LA COLLISION
	; ========================================================================
	; Si on arrive ici : bumpers pressés, gérer la collision
	
	; Arrêter le chronomètre et calculer la distance parcourue
	BL CHRONO_STOP_DISTANCE		; r0 = distance en cm
	
	; Stocker la distance dans le tableau distances[r7]
	LDR r8, =distances
	STR r0, [r8, r7, LSL #2]	; distances[r7] = r0
	
	; Arrêter les moteurs avant de tourner
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Faire clignoter la LED gauche N fois (N = distance en cm)
	; r0 contient déjà la distance calculée
	LDR r0, [r8, r7, LSL #2]	; Recharger la distance depuis distances[r7]
	BL LED_GAUCHE_BLINK_N_TIMES
	
	; Rotation de 90° dans la direction choisie au démarrage
	; r4 = 1 : rotation gauche
	; r4 = 2 : rotation droite
	CMP r4, #1
	BEQ rotate_left
	
rotate_right
	BL ROTATION_90_DROITE
	B continue_loop
	
rotate_left
	BL ROTATION_90_GAUCHE
	
continue_loop
	; ========================================================================
	; 4. INCRÉMENTER LE COMPTEUR DE ROTATIONS
	; ========================================================================
	ADD r7, r7, #1				; Incrémenter le compteur de rotations
	
	; Vérifier si on a atteint le nombre maximum de rotations
	CMP r7, #MAX_ROTATIONS
	BGE stop_robot				; Si r7 >= 4, arrêter le robot
	
	; Sinon, continuer : retourner au début pour repartir en ligne droite
	B loop

; ============================================================================
; ARRÊT DU ROBOT
; ============================================================================
; Le robot a effectué 4 rotations, on arrête tout et on boucle indéfiniment
stop_robot
	; S'assurer que les moteurs sont bien arrêtés
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; ========================================================================
	; 4. ARRÊT DU ROBOT APRÈS 4 ROTATIONS
	; ========================================================================
	; ARRÊT FINAL APRÈS 4 ROTATIONS
	; ========================================================================
	; Arrêter les moteurs
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Boucle infinie : le robot reste arrêté
end_loop
	B end_loop

    END 