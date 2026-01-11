	
	;; RK - Evalbot (Cortex M3 de Texas Instrument)
   	
	AREA    |.text|, CODE, READONLY
 
; CONSTANTS DECLARATION

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

__main
	; ========================================================================
	; INITIALISATION
	; ========================================================================
	; Initialiser les moteurs, bumpers et switches
	BL MOTEUR_INIT
	BL BUMPERS_INIT
	BL SWITCHES_INIT
	
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
	; 4. Retourner au début : le robot repart en ligne droite
	B loop

    END 