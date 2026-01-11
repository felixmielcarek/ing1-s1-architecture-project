	
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
	
	IMPORT BUMPERS_INIT
	IMPORT READ_BUMPERS

__main
	; Initialize motors and bumpers
	BL MOTEUR_INIT
	BL BUMPERS_INIT

loop	
	; 1. Robot goes front
	; Configurer la direction AVANT d'activer les moteurs
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; ========================================================================
	; 2. Vérification continue des bumpers pendant que le robot avance
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
	
	; Si on arrive ici : bumpers PRESSÉS (r5==0), gérer la collision
	; Arrêter les moteurs avant de tourner
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Rotation de 90° vers la gauche pour éviter l'obstacle
	BL ROTATION_90_GAUCHE

	; 3. Retourner au début : le robot repart en ligne droite
	B loop

    END 