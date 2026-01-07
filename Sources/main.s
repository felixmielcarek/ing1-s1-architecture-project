	
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

	IMPORT ROTATION_90_GAUCHE
	IMPORT ROTATION_90_DROITE
	
	IMPORT SWITCHES_INIT
	IMPORT ATTENTE_SWITCH
	IMPORT LIRE_DIRECTION
	
	IMPORT LEDS_INIT
	IMPORT LEDS_ON
	IMPORT LEDS_OFF
	IMPORT LEDS_AVANCE
	IMPORT LEDS_ROTATION

; Variable pour stocker la direction choisie
DIRECTION_CHOISIE	EQU		0x20000000  ; Adresse en RAM

__main
	; Initialisation du système
	BL MOTEUR_INIT
	BL SWITCHES_INIT
	BL LEDS_INIT
	
	; Attendre que l'utilisateur choisisse la direction
	BL ATTENTE_SWITCH
	; R0 contient maintenant 0 (gauche) ou 1 (droite)
	
	; Sauvegarder la direction en mémoire
	ldr r1, =DIRECTION_CHOISIE
	str r0, [r1]
	
	; Allumer les LEDs quand on avance tout droit
	BL LEDS_AVANCE
	
	; Démarrer les moteurs
	BL MOTEUR_GAUCHE_ON
	BL MOTEUR_DROIT_ON
	
	; Charger la direction et effectuer la rotation
	ldr r1, =DIRECTION_CHOISIE
	ldr r0, [r1]
	
	; Éteindre les LEDs pendant la rotation
	BL LEDS_ROTATION
	
	; Rotation selon la direction choisie
	cmp r0, #0
	beq rotation_gauche
	b rotation_droite

rotation_gauche
	BL ROTATION_90_GAUCHE
	b fin_rotation

rotation_droite
	BL ROTATION_90_DROITE

fin_rotation
	; Rallumer les LEDs après la rotation
	BL LEDS_AVANCE
	
	; Arrêter les moteurs
	BL MOTEUR_GAUCHE_OFF
	BL MOTEUR_DROIT_OFF
	
	; Éteindre les LEDs à la fin
	BL LEDS_OFF

    END 