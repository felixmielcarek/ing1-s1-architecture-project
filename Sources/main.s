	
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
	
	IMPORT OLED_INIT
	IMPORT OLED_CLEAR
	IMPORT OLED_SET_CURSOR
	IMPORT OLED_WRITE_STRING
	
	IMPORT ready_msg
	IMPORT finish_msg
	IMPORT done_msg

__main
	; ========================================================================
	; INITIALISATION
	; ========================================================================
	; Initialiser les moteurs, bumpers, switches et écran OLED
	BL MOTEUR_INIT
	BL BUMPERS_INIT
	BL SWITCHES_INIT
	BL OLED_INIT
	
	; Effacer l'écran au démarrage
	BL OLED_CLEAR
	
	; Afficher message de démarrage (écran 96x16 = 2 pages seulement)
	MOV r0, #0				; Colonne 0
	MOV r1, #0				; Page 0 (ligne du haut)
	BL OLED_SET_CURSOR
	LDR r0, =ready_msg
	BL OLED_WRITE_STRING
	
	; ========================================================================
	; ATTENTE DU CHOIX DE DIRECTION
	; ========================================================================
	; Attendre que l'utilisateur presse un switch pour choisir la direction
	; de rotation lors des collisions :
	; - Switch 1 (SW1) : rotation à GAUCHE
	; - Switch 2 (SW2) : rotation à DROITE
	; Résultat dans r4 : 1=gauche, 2=droite
	BL WAIT_SWITCH_PRESS
	
	; r4 contient maintenant la direction choisie (1 ou 2)
	; Cette valeur sera utilisée à chaque collision
	
	; ========================================================================
	; INITIALISATION DU COMPTEUR DE ROTATIONS
	; ========================================================================
	; r7 = compteur de rotations (commence à 0)
	MOV r7, #0

loop	
	; ========================================================================
	; 1. AVANCER EN LIGNE DROITE
	; ========================================================================
	; Configurer la direction AVANT d'activer les moteurs
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; ========================================================================
	; 2. VÉRIFICATION CONTINUE DES BUMPERS
	; ========================================================================
	; FONCTIONNEMENT :
	; - READ_BUMPERS lit les pins PE0 et PE1 (avec pull-up activés)
	; - Bumpers NON pressés : r5 = 0x03 (les deux bits à 1 grâce au pull-up)
	; - Bumpers pressés : r5 = 0x00 (court-circuit à la masse)
	; - CMP r5, #0x00 met le flag Z=1 si r5==0 (bumpers pressés)
	; - BNE = Branch if Not Equal, donc boucle tant que r5 != 0 (NON pressés)
	; ========================================================================
check_bumpers
	BL READ_BUMPERS
	BNE check_bumpers			; Si bumpers NON pressés (r5!=0), continuer à vérifier
	
	; ========================================================================
	; 3. GESTION DE LA COLLISION
	; ========================================================================
	; Si on arrive ici : bumpers PRESSÉS (r5==0), gérer la collision
	; Arrêter les moteurs avant de tourner
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
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
	; AFFICHAGE DU MESSAGE SUR L'ÉCRAN OLED
	; ========================================================================
	; 4. ARRÊT DU ROBOT APRÈS 4 ROTATIONS
	; ========================================================================
	; Arrêter les moteurs
	BL MOTEUR_DROIT_OFF
	BL MOTEUR_GAUCHE_OFF
	
	; Afficher message de fin sur l'écran OLED
	; Ligne 1 : "4 ROTATIONS"
	; Ligne 2 : "TERMINE!"
	BL OLED_CLEAR
	
	; Position curseur ligne 1 (page 0)
	MOV r0, #0				; Colonne 0
	MOV r1, #0				; Page 0 (ligne du haut)
	BL OLED_SET_CURSOR
	
	; Afficher "4 ROTATIONS"
	LDR r0, =finish_msg
	BL OLED_WRITE_STRING
	
	; Position curseur ligne 2 (page 1)
	MOV r0, #0				; Colonne 0
	MOV r1, #1				; Page 1 (ligne du bas)
	BL OLED_SET_CURSOR
	
	; Afficher "TERMINE!"
	LDR r0, =done_msg
	BL OLED_WRITE_STRING
	
	; Boucle infinie : le robot reste arrêté avec le message affiché
end_loop
	B end_loop

    END 