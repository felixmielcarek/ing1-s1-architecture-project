;; RK - Evalbot (Cortex M3 de Texas Instrument)
;; Gestion des switches pour déterminer la direction de rotation

;Documentation Evalbot:
;Switch gauche (SW1) => PG3
;Switch droit (SW2) => PG4

;; GPIO Port G configuration
PORTG_BASE		EQU		0x40026000
GPIODATA_G		EQU		PORTG_BASE
GPIODIR_G		EQU		PORTG_BASE+0x00000400
GPIOPUR_G		EQU		PORTG_BASE+0x00000510	; Pull-Up Resistor
GPIODEN_G		EQU		PORTG_BASE+0x0000051C

SYSCTL_RCGC2	EQU		0x400FE108

GPIO_3			EQU		0x08	; Switch gauche (SW1)
GPIO_4			EQU		0x10	; Switch droit (SW2)

DIRECTION_GAUCHE	EQU		0	; Valeur retournée si switch gauche pressé
DIRECTION_DROITE	EQU		1	; Valeur retournée si switch droit pressé

		AREA    |.text|, CODE, READONLY
		ENTRY
		
		EXPORT	SWITCHES_INIT
		EXPORT	LIRE_DIRECTION
		EXPORT	ATTENTE_SWITCH

SWITCHES_INIT
		; Active l'horloge pour le Port G
		ldr r6, =SYSCTL_RCGC2
		ldr	r0, [r6]
        ORR	r0, r0, #0x40  ; Bit 6 = Port G
        str r0, [r6]
		
		nop
		nop
		nop
		
		; Configuration PG3 et PG4 en ENTRÉE (0 dans GPIODIR)
		ldr r6, =GPIODIR_G
		ldr	r0, [r6]
		bic	r0, r0, #(GPIO_3+GPIO_4)  ; Effacer les bits pour entrée
		str	r0, [r6]
		
		; Activation des résistances de rappel (Pull-Up) sur PG3 et PG4
		ldr r6, =GPIOPUR_G
		ldr	r0, [r6]
		ORR	r0, r0, #(GPIO_3+GPIO_4)
		str	r0, [r6]
		
		; Activation numérique sur PG3 et PG4
		ldr r6, =GPIODEN_G
		ldr	r0, [r6]
		ORR	r0, r0, #(GPIO_3+GPIO_4)
		str	r0, [r6]
		
		BX	LR

; Fonction: LIRE_DIRECTION
; Retourne dans R0: 0 si switch gauche pressé, 1 si switch droit pressé
LIRE_DIRECTION
		push {r4, lr}
		
		; Lire l'état des switches
		ldr	r6, =(GPIODATA_G+((GPIO_3+GPIO_4)<<2))
		ldr	r0, [r6]
		
		; Vérifie switch gauche (PG3) - bit 3
		tst	r0, #GPIO_3
		beq	direction_gauche_detectee
		
		; Vérifie switch droit (PG4) - bit 4
		tst	r0, #GPIO_4
		beq	direction_droite_detectee
		
		; Aucun switch pressé, retourner valeur par défaut (gauche)
		mov	r0, #DIRECTION_GAUCHE
		b	fin_lire_direction

direction_gauche_detectee
		mov	r0, #DIRECTION_GAUCHE
		b	fin_lire_direction

direction_droite_detectee
		mov	r0, #DIRECTION_DROITE

fin_lire_direction
		pop {r4, pc}

; Fonction: ATTENTE_SWITCH
; Attend qu'un switch soit pressé et retourne la direction choisie
; Retourne dans R0: 0 (gauche) ou 1 (droit)
ATTENTE_SWITCH
		push {r4, lr}
		
boucle_attente
		; Lire l'état des switches
		ldr	r6, =(GPIODATA_G+((GPIO_3+GPIO_4)<<2))
		ldr	r0, [r6]
		
		; Vérifier switch gauche (PG3)
		tst	r0, #GPIO_3
		beq	switch_gauche_presse
		
		; Vérifier switch droit (PG4)
		tst	r0, #GPIO_4
		beq	switch_droit_presse
		
		; Aucun switch pressé, continuer la boucle
		b	boucle_attente

switch_gauche_presse
		; Attendre relâchement du switch (anti-rebond)
		bl	DEBOUNCE_DELAY
		mov	r0, #DIRECTION_GAUCHE
		b	fin_attente_switch

switch_droit_presse
		; Attendre relâchement du switch (anti-rebond)
		bl	DEBOUNCE_DELAY
		mov	r0, #DIRECTION_DROITE
		b	fin_attente_switch

fin_attente_switch
		pop {r4, pc}

; Délai anti-rebond pour les switches
DEBOUNCE_DELAY
		push {r4, lr}
		mov	r4, #0x10000  ; Délai court
delay_loop
		subs r4, r4, #1
		bne	delay_loop
		pop {r4, pc}

		END
