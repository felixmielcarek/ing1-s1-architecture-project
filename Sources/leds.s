;; RK - Evalbot (Cortex M3 de Texas Instrument)
;; Gestion des LEDs pour indiquer le mouvement du robot

;Documentation Evalbot:
;LED0 (D1) => PF4
;LED1 (D2) => PF5

;; GPIO Port F configuration
PORTF_BASE		EQU		0x40025000
GPIODATA_F		EQU		PORTF_BASE
GPIODIR_F		EQU		PORTF_BASE+0x00000400
GPIODR2R_F		EQU		PORTF_BASE+0x00000500
GPIODEN_F		EQU		PORTF_BASE+0x0000051C

SYSCTL_RCGC2	EQU		0x400FE108

GPIO_4			EQU		0x10	; LED0 (D1)
GPIO_5			EQU		0x20	; LED1 (D2)

LED_MASK		EQU		(GPIO_4+GPIO_5)

		AREA    |.text|, CODE, READONLY
		ENTRY
		
		EXPORT	LEDS_INIT
		EXPORT	LEDS_ON
		EXPORT	LEDS_OFF
		EXPORT	LED_GAUCHE_ON
		EXPORT	LED_GAUCHE_OFF
		EXPORT	LED_DROITE_ON
		EXPORT	LED_DROITE_OFF
		EXPORT	LEDS_AVANCE
		EXPORT	LEDS_ROTATION

; Initialisation des LEDs
LEDS_INIT
		; Active l'horloge pour le Port F
		ldr r6, =SYSCTL_RCGC2
		ldr	r0, [r6]
        ORR	r0, r0, #0x20  ; Bit 5 = Port F
        str r0, [r6]
		
		nop
		nop
		nop
		
		; Configure PF4 et PF5 en OUTPUT
		ldr r6, =GPIODIR_F
		ldr	r0, [r6]
		ORR	r0, r0, #LED_MASK
		str	r0, [r6]
		
		; Courant de sortie 2mA
		ldr r6, =GPIODR2R_F
		ldr	r0, [r6]
		ORR	r0, r0, #LED_MASK
		str	r0, [r6]
		
		; Digital Enable sur PF4 et PF5
		ldr r6, =GPIODEN_F
		ldr	r0, [r6]
		ORR	r0, r0, #LED_MASK
		str	r0, [r6]
		
		; Éteindre les LEDs au départ
		ldr	r6, =(GPIODATA_F+(LED_MASK<<2))
		mov	r0, #0
		str	r0, [r6]
		
		BX	LR

; Allumer les 2 LEDs
LEDS_ON
		ldr	r6, =(GPIODATA_F+(LED_MASK<<2))
		mov	r0, #LED_MASK
		str	r0, [r6]
		BX	LR

; Éteindre les 2 LEDs
LEDS_OFF
		ldr	r6, =(GPIODATA_F+(LED_MASK<<2))
		mov	r0, #0
		str	r0, [r6]
		BX	LR

; Allumer LED gauche (LED0/D1 - PF4)
LED_GAUCHE_ON
		ldr	r6, =(GPIODATA_F+(GPIO_4<<2))
		mov	r0, #GPIO_4
		str	r0, [r6]
		BX	LR

; Éteindre LED gauche
LED_GAUCHE_OFF
		ldr	r6, =(GPIODATA_F+(GPIO_4<<2))
		mov	r0, #0
		str	r0, [r6]
		BX	LR

; Allumer LED droite (LED1/D2 - PF5)
LED_DROITE_ON
		ldr	r6, =(GPIODATA_F+(GPIO_5<<2))
		mov	r0, #GPIO_5
		str	r0, [r6]
		BX	LR

; Éteindre LED droite
LED_DROITE_OFF
		ldr	r6, =(GPIODATA_F+(GPIO_5<<2))
		mov	r0, #0
		str	r0, [r6]
		BX	LR

; Mode avancement: allume les 2 LEDs
LEDS_AVANCE
		b	LEDS_ON

; Mode rotation: clignotement ou une seule LED
; Ici on les éteint toutes les deux pendant la rotation
LEDS_ROTATION
		b	LEDS_OFF

		END
