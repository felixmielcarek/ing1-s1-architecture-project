	
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
	;BL BUMPERS_INIT

loop	
	; 1. Robot goes front
	BL MOTEUR_GAUCHE_AVANT
	BL MOTEUR_DROIT_AVANT
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; 2. When bumpers 1 or 2 or both are activated, rotate 90° left
check_bumpers
	;BL READ_BUMPERS
	;BEQ check_bumpers			; If bumpers NOT pressed (r5==0), keep checking
	
	; Bumpers pressed (r5!=0), handle collision
	; Rotate 90° left
	;BL ROTATION_90_GAUCHE

	;BL MOTEUR_GAUCHE_OFF
	;BL MOTEUR_DROIT_OFF
	
	; 3. Robot goes front again (loop back)
	B loop

    END 