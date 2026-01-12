;; RK - Evalbot (Cortex M3 de Texas Instrument); 
; programme - Pilotage 2 Moteurs Evalbot par PWM tout en ASM (configure les pwms + GPIO)

;Les pages se réfèrent au datasheet lm3s9b92.pdf

;Cablage :
;pin 10/PD0/PWM0 => input PWM du pont en H DRV8801RT
;pin 11/PD1/PWM1 => input Phase_R  du pont en H DRV8801RT
;pin 12/PD2		 => input SlowDecay commune aux 2 ponts en H
;pin 98/PD5		 => input Enable 12v du conv DC/DC 
;pin 86/PH0/PWM2 => input PWM du 2nd pont en H
;pin 85/PH1/PWM3 => input Phase du 2nd pont en H	

;; Hexa corresponding values to pin numbers
GPIO_0		EQU		0x1
GPIO_1		EQU		0x2
GPIO_2		EQU		0x4
GPIO_5		EQU		0x20

;; pour enable clock    0x400FE000
SYSCTL_RCGC0	EQU		0x400FE100		;SYSCTL_RCGC0: offset 0x100 (p271 datasheet de lm3s9b92.pdf)
SYSCTL_RCGC2	EQU		0x400FE108		;SYSCTL_RCGC2: offset 0x108 (p291 datasheet de lm3s9b92.pdf)

;; General-Purpose Input/Outputs (GPIO) configuration
PORTD_BASE		EQU		0x40007000
GPIODATA_D		EQU		PORTD_BASE
GPIODIR_D		EQU		PORTD_BASE+0x00000400
GPIODR2R_D		EQU		PORTD_BASE+0x00000500
GPIODEN_D		EQU		PORTD_BASE+0x0000051C
GPIOPCTL_D		EQU		PORTD_BASE+0x0000052C ; GPIO Port Control (GPIOPCTL), offset 0x52C; p444
GPIOAFSEL_D		EQU		PORTD_BASE+0x00000420 ; GPIO Alternate Function Select (GPIOAFSEL), offset 0x420; p426

PORTH_BASE		EQU		0x40027000
GPIODATA_H		EQU		PORTH_BASE
GPIODIR_H		EQU		PORTH_BASE+0x00000400
GPIODR2R_H		EQU		PORTH_BASE+0x00000500
GPIODEN_H		EQU		PORTH_BASE+0x0000051C
GPIOPCTL_H		EQU		PORTH_BASE+0x0000052C ; GPIO Port Control (GPIOPCTL), offset 0x52C; p444
GPIOAFSEL_H		EQU		PORTH_BASE+0x00000420 ; GPIO Alternate Function Select (GPIOAFSEL), offset 0x420; p426

;; Pulse Width Modulator (PWM) configuration
PWM_BASE		EQU		0x040028000 	   ;BASE des Block PWM p.1138
PWMENABLE		EQU		PWM_BASE+0x008	   ; p1145

;Block PWM0 pour sorties PWM0 et PWM1 (moteur 1)
PWM0CTL			EQU		PWM_BASE+0x040 ;p1167
PWM0LOAD		EQU		PWM_BASE+0x050
PWM0CMPA		EQU		PWM_BASE+0x058
PWM0CMPB		EQU		PWM_BASE+0x05C
PWM0GENA		EQU		PWM_BASE+0x060
PWM0GENB		EQU		PWM_BASE+0x064

;Block PWM1 pour sorties PWM1 et PWM2 (moteur 2)
PWM1CTL			EQU		PWM_BASE+0x080 
PWM1LOAD		EQU		PWM_BASE+0x090
PWM1CMPA		EQU		PWM_BASE+0x098
PWM1CMPB		EQU		PWM_BASE+0x09C
PWM1GENA		EQU		PWM_BASE+0x0A0
PWM1GENB		EQU		PWM_BASE+0x0A4


VITESSE			EQU		0x192	; Valeures plus petites => Vitesse plus rapide exemple 0x192
;VITESSE			EQU		0x001		; Valeures plus grandes => Vitesse moins rapide exemple 0x1B2

; Configuration du délai pour rotation 90° : nombre d'itérations de 0.1 seconde
; IMPORTANT : L'horloge CPU par défaut du LM3S1968 est 16 MHz (oscillateur RC interne)
; Sans configuration de la PLL, le système tourne à 16 MHz
; Avec CPU à 16 MHz, SysTick compte de (1600000-1) à 0 = 0.1 seconde
ROTATION_TIME	EQU		0x23	; 35 itérations x 0.1s = 3.5 secondes
;ROTATION_TIME	EQU		0x1E	; 30 itérations x 0.1s = 3.0 secondes
;ROTATION_TIME	EQU		0x32	; 50 itérations x 0.1s = 5.0 secondes

; Fréquences du système
F_CPU_REAL		EQU		16000000	; Fréquence CPU réelle = 16 MHz (oscillateur RC interne par défaut)
F_PWM 			EQU 	16000		; Fréquence PWM cible pour moteurs = 16 kHz

; Calcul de la période PWM avec la fréquence réelle :
; PWM_PERIOD = F_CPU_REAL / F_PWM = 16000000 / 16000 = 1000
; En mode up-down (compte de 0 à LOAD puis de LOAD à 0), on divise par 2
; PWM_LOAD = 1000 / 2 = 500 = 0x1F4
PWM_LOAD		EQU		(F_CPU_REAL / F_PWM) / 2	; = 781 (0x30D)
						
		AREA    |.text|, CODE, READONLY
		ENTRY
		
		;; The EXPORT command specifies that a symbol can be accessed by other shared objects or executables.
		EXPORT	MOTEUR_INIT
		EXPORT	MOTEUR_DROIT_ON
		EXPORT  MOTEUR_DROIT_OFF
		EXPORT  MOTEUR_DROIT_AVANT
		EXPORT  MOTEUR_DROIT_ARRIERE
		EXPORT  MOTEUR_DROIT_INVERSE	
		EXPORT	MOTEUR_GAUCHE_ON
		EXPORT  MOTEUR_GAUCHE_OFF
		EXPORT  MOTEUR_GAUCHE_AVANT
		EXPORT  MOTEUR_GAUCHE_ARRIERE
		EXPORT  MOTEUR_GAUCHE_INVERSE
		EXPORT	ROTATION_90_GAUCHE
		EXPORT	ROTATION_90_DROITE


MOTEUR_INIT	
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		ldr r6, = SYSCTL_RCGC0
		ldr	r0, [R6]
        ORR	r0, r0, #0x00100000  ;;bit 20 = PWM recoit clock: ON (p271) 
        str r0, [r6]

	;ROM_SysCtlPWMClockSet(SYSCTL_PWMDIV_1);PWM clock is processor clock /1
	;Je ne fais rien car par defaut = OK!!
	;*(int *) (0x400FE060)= *(int *)(0x400FE060)...;
	
  	;RCGC2 :  Enable port D GPIO(p291 ) car Moteur Droit sur port D 
		ldr r6, = SYSCTL_RCGC2
		ldr	r0, [R6] 		
        ORR	r0, r0, #0x08  ;; Enable port D GPIO 
        str r0, [r6]

	;MOT2 : RCGC2 :  Enable port H GPIO  (2eme moteurs)
		ldr r6, = SYSCTL_RCGC2
		ldr	r0, [R6] 
        ORR	r0, r0, #0x80  ;; Enable port H GPIO 
        str r0, [r6] 
		
		nop
		nop
		nop
	 
	;;Pin muxing pour PWM, port D, reg. GPIOPCTL(p444), 4bits de PCM0=0001<=>PWM (voir p1261)
	;;il faut mettre 1 pour avoir PD0=PWM0 et PD1=PWM1
		ldr r6, = GPIOPCTL_D
		;ldr	r0, [R6] 	 ;;	*(int *)(0x40007000+0x0000052C)=1;
        ;ORR	r0, r0, #0x01 ;; Port D, pin 1 = PWM 
		mov	r0, #0x01  
        str r0, [r6]
		
	;;MOT2 : Pin muxing pour PWM, port H, reg. GPIOPCTL(p444), 4bits de PCM0=0001<=>PWM (voir p1261)
	;;il faut mettre mux = 2 pour avoir PH0=PWM2 et PH1=PWM3
		ldr r6, = GPIOPCTL_H 
		mov	r0, #0x02 
        str r0, [r6]
		
	;;Alternate Function Select (p 426), PD0 utilise alernate fonction (PWM au dessus)
	;;donc PD0 = 1
		ldr r6, = GPIOAFSEL_D
		ldr	r0, [R6] 	  ;*(int *)(0x40007000+0x00000420)= *(int *)(0x40007000+0x00000420) | 0x00000001;
        ORR	r0, r0, #0x01 ;
        str r0, [r6]

	;;MOT2 : Alternate Function Select (p 426), PH0 utilise PWM donc Alternate funct
	;;donc PH0 = 1
		ldr r6, = GPIOAFSEL_H
		ldr	r0, [R6] 	  ;*(int *)(0x40007000+0x00000420)= *(int *)(0x40007000+0x00000420) | 0x00000001;
        ORR	r0, r0, #0x01 ;
        str r0, [r6]
	
	;;-----------PWM0 pour moteur 1 connecté à PD0
	;;PWM0 produit PWM0 et PWM1 output
	;;Config Modes PWM0 + mode GenA + mode GenB
		ldr r6, = PWM0CTL
		mov	r0, #2		;Mode up-down-up-down, pas synchro
        str r0, [r6]	
		
		ldr r6, =PWM0GENA ;en decomptage, qd comparateurA = compteur => sortie pwmA=0
						;en comptage croissant, qd comparateurA = compteur => sortie pwmA=1
		mov	r0,	#0x0B0 	;0B0=10110000 => ACTCMPBD=00 (B down:rien), ACTCMPBU=00(B up rien)
		str r0, [r6]	;ACTCMPAD=10 (A down:pwmA low), ACTCMPAU=11 (A up:pwmA high) , ACTLOAD=00,ACTZERO=00  
		
		ldr r6, =PWM0GENB;en comptage croissant, qd comparateurB = compteur => sortie pwmA=1
		mov	r0,	#0x0B00	;en decomptage, qd comparateurB = compteur => sortie pwmB=0
		str r0, [r6]	
	;Config Compteur, comparateur A et comparateur B
  	;;#define PWM_PERIOD (ROM_SysCtlClockGet() / 16000),
	;;en mesure : SysCtlClockGet=0F42400h, /16=0x3E8, 
	;;on divise par 2 car moteur 6v sur alim 12v
		ldr	r6, =PWM0LOAD ;PWM0LOAD=periode/2 =0x1F4
		mov r0,	#0x1F4
		str	r0,[r6]
		
		ldr	r6, =PWM0CMPA ;Valeur rapport cyclique : pour 10% => 1C2h si clock = 0F42400
		mov	r0, #VITESSE
		str	r0, [r6]  
		
		ldr	r6, =PWM0CMPB ;PWM0CMPB recoit meme valeur. (rapport cyclique depend de CMPA)
		mov	r0,	#0x1F4	
		str	r0,	[r6]
		
	;Control PWM : active PWM Generator 0 (p1167): Enable+up/down + Enable counter debug mod
		ldr	r6, =PWM0CTL 
		ldr	r0, [r6]	
		ORR	r0,	r0,	#0x07
		str	r0,	[r6]

	;;-----------PWM2 pour moteur 2 connecté à PH0
	;;PWM1block produit PWM2 et PWM3 output
		;;Config Modes PWM2 + mode GenA + mode GenB
		ldr r6, = PWM1CTL
		mov	r0, #2		;Mode up-down-up-down, pas synchro
        str r0, [r6]	;*(int *)(0x40028000+0x040)=2;
		
		ldr r6, =PWM1GENA ;en decomptage, qd comparateurA = compteur => sortie pwmA=0
						;en comptage croissant, qd comparateurA = compteur => sortie pwmA=1
		mov	r0,	#0x0B0 	;0B0=10110000 => ACTCMPBD=00 (B down:rien), ACTCMPBU=00(B up rien)
		str r0, [r6]	;ACTCMPAD=10 (A down:pwmA low), ACTCMPAU=11 (A up:pwmA high) , ACTLOAD=00,ACTZERO=00  
		
 		;*(int *)(0x40028000+0x060)=0x0B0; //
		ldr r6, =PWM1GENB	;*(int *)(0x40028000+0x064)=0x0B00;
		mov	r0,	#0x0B00	;en decomptage, qd comparateurB = compteur => sortie pwmB=0
		str r0, [r6]	;en comptage croissant, qd comparateurB = compteur => sortie pwmA=1
	;Config Compteur, comparateur A et comparateur B
  	;;#define PWM_PERIOD (ROM_SysCtlClockGet() / 16000),
	;;en mesure : SysCtlClockGet=0F42400h, /16=0x3E8, 
	;;on divise par 2 car moteur 6v sur alim 12v
		;*(int *)(0x40028000+0x050)=0x1F4; //PWM0LOAD=periode/2 =0x1F4
		ldr	r6, =PWM1LOAD
		mov r0,	#0x1F4
		str	r0,[r6]
		
		ldr	r6, =PWM1CMPA ;Valeur rapport cyclique : pour 10% => 1C2h si clock = 0F42400
		mov	r0,	#VITESSE
		str	r0, [r6]  ;*(int *)(0x40028000+0x058)=0x01C2;
		
		ldr	r6, =PWM1CMPB ;PWM0CMPB recoit meme valeur. (CMPA depend du rapport cyclique)
		mov	r0,	#0x1F4	; *(int *)(0x40028000+0x05C)=0x1F4; 
		str	r0,	[r6]
		
	;Control PWM : active PWM Generator 0 (p1167): Enable+up/down + Enable counter debug mod
		ldr	r6, =PWM1CTL 
		ldr	r0, [r6]	;*(int *) (0x40028000+0x40)= *(int *)(0x40028000+0x40) | 0x07;
		ORR	r0,	r0,	#0x07
		str	r0,	[r6]		
		
	;;-----Fin config des PWMs			
		
	;PORT D OUTPUT pin0 (pwm)=pin1(direction)=pin2(slow decay)=pin5(12v enable)
		ldr	r6, =GPIODIR_D 
		ldr	r0, [r6]
		ORR	r0,	#(GPIO_0+GPIO_1+GPIO_2+GPIO_5)
		str	r0,[r6]
	;Port D, 2mA les meme
		ldr	r6, =GPIODR2R_D ; 
		ldr	r0, [r6]
		ORR	r0,	#(GPIO_0+GPIO_1+GPIO_2+GPIO_5)
		str	r0,[r6]
	;Port D, Digital Enable
		ldr	r6, =GPIODEN_D ;
		ldr	r0, [r6]
		ORR	r0,	#(GPIO_0+GPIO_1+GPIO_2+GPIO_5)	
		str	r0,[r6]	
	;Port D : mise à 1 de slow Decay et 12V et mise à 0 pour dir et pwm
		ldr	r6, =(GPIODATA_D+((GPIO_0+GPIO_1+GPIO_2+GPIO_5)<<2)) 
		mov	r0, #(GPIO_2+GPIO_5) ; #0x24
		str	r0,[r6]
		
	;MOT2, PH1 pour sens moteur ouput
		ldr	r6, =GPIODIR_H 
		mov	r0,	#0x03	; 
		str	r0,[r6]
	;Port H, 2mA les meme
		ldr	r6, =GPIODR2R_H
		mov r0, #0x03	
		str	r0,[r6]
	;Port H, Digital Enable
		ldr	r6, =GPIODEN_H
		mov r0, #0x03	
		str	r0,[r6]	
	;Port H : mise à 1 pour dir 
		ldr	r6, =(GPIODATA_H +(GPIO_1<<2))
		mov	r0, #0x02
		str	r0,[r6]		
		
		POP {r6, PC}				; Restaurer registres et retourner

;Enable PWM0 (bit 0) et PWM2 (bit 2) p1145 
;Attention ici c'est les sorties PWM0 et PWM2
;qu'on controle, pas les blocks PWM0 et PWM1!!!
MOTEUR_DROIT_ON
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Enable sortie PWM0 (bit 0), p1145 
		ldr	r6,	=PWMENABLE
		ldr r0, [r6]
		orr r0,	#0x01 ;bit 0 à 1
		str	r0,	[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_DROIT_OFF
		PUSH {r6, LR}				; Sauvegarder registres préservés
		 
		ldr	r6,	=PWMENABLE
		ldr r0,	[r6]
		and	r0,	#0x0E	;bit 0 à 0
		str	r0,	[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_GAUCHE_ON
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		ldr	r6,	=PWMENABLE
		ldr	r0, [r6]
		orr	r0,	#0x04	;bit 2 à 1
		str	r0,	[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_GAUCHE_OFF
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		ldr	r6,	=PWMENABLE
		ldr	r0,	[r6]
		and	r0,	#0x0B	;bit 2 à 0
		str	r0,	[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_DROIT_ARRIERE
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_D+(GPIO_1<<2)) 
		mov	r0, #0
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_DROIT_AVANT
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_D+(GPIO_1<<2)) 
		mov	r0, #2
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_GAUCHE_ARRIERE
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_H+(GPIO_1<<2)) 
		mov	r0, #2 ; contraire du moteur Droit
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner		

MOTEUR_GAUCHE_AVANT
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_H+(GPIO_1<<2)) 
		mov	r0, #0
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner		

MOTEUR_DROIT_INVERSE
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_D+(GPIO_1<<2)) 
		ldr	r1, [r6]
		EOR	r0, r1, #GPIO_1
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner

MOTEUR_GAUCHE_INVERSE
		PUSH {r6, LR}				; Sauvegarder registres préservés
		
		;Inverse Direction (GPIO_D1)
		ldr	r6, =(GPIODATA_H+(GPIO_1<<2)) 
		ldr	r1, [r6]
		EOR	r0, r1, #GPIO_1
		str	r0,[r6]
		
		POP {r6, PC}				; Restaurer registres et retourner
		
; ============================================================================
; DELAY_90_DEG - Génère un délai temporel fixe pour rotation de 90 degrés
; ============================================================================
; Utilise le SysTick Timer (timer système ARM Cortex-M3) pour créer un délai
; précis. Le SysTick est un compteur 24-bit qui décompte de la valeur de
; reload vers 0, puis génère un flag quand il atteint 0.
;
; Principe de fonctionnement :
; 1. Configure SysTick pour compter 5000000 cycles (= 0.1 seconde à 50 MHz)
; 2. Répète cette attente ROTATION_TIME fois (ex: 35 fois = 3.5 secondes)
; 3. Chaque fois que le compteur atteint 0, le bit COUNTFLAG est mis à 1
; 4. La lecture du registre SYST_CSR efface automatiquement le COUNTFLAG
;
; Registres SysTick utilisés :
; - SYST_RVR (0xE000E014) = Reload Value Register : valeur de rechargement
; - SYST_CSR (0xE000E010) = Control and Status Register : contrôle & status
;
; Registres utilisés : R0, R1, R2, R3
; Durée totale : ROTATION_TIME x 0.1 seconde
; ============================================================================
DELAY_90_DEG
		; ===== ÉTAPE 1 : Configuration de la période du SysTick =====
		; Charger l'adresse du registre SYST_RVR (SysTick Reload Value Register)
        LDR R0, =0xE000E014     
		
		; Calculer la valeur de reload pour 0.1 seconde
		; Horloge CPU RÉELLE = 16 MHz = 16 000 000 cycles/seconde
		; (L'oscillateur RC interne par défaut du LM3S1968 est à 16 MHz)
		; Pour 0.1 seconde : 16 000 000 / 10 = 1 600 000 cycles
		; Le compteur va de (valeur-1) à 0, donc on charge 1600000-1 = 1599999 = 0x186A00-1 = 0x1869FF
        LDR R1, =1600000-1      
		
		; Écrire la valeur de reload dans SYST_RVR
        STR R1, [R0]

		; ===== ÉTAPE 2 : Démarrer le SysTick Timer =====
		; Charger l'adresse du registre SYST_CSR (Control and Status Register)
        LDR R0, =0xE000E010     
		
		; Configurer les bits de contrôle :
		; Bit 0 (ENABLE)    = 1 : Active le compteur
		; Bit 1 (TICKINT)   = 0 : Pas d'interruption (on utilise le polling)
		; Bit 2 (CLKSOURCE) = 1 : Utilise l'horloge CPU (pas divisée)
		; Valeur = 0b101 = 5
        MOV R1, #5              
		
		; Démarrer le timer en écrivant dans SYST_CSR
        STR R1, [R0]

		; ===== ÉTAPE 3 : Initialiser le compteur d'itérations =====
		; R2 servira de compteur pour le nombre de périodes de 0.1s à attendre
        MOV R2, #ROTATION_TIME	; Ex: 35 pour attendre 3.5 secondes

; ============================================================================
; WAIT_SEC - Boucle externe : répète l'attente de 0.1 seconde plusieurs fois
; ============================================================================
WAIT_SEC
		; À chaque itération de cette boucle, on attend que le SysTick
		; compte de 5000000-1 jusqu'à 0 (= 0.1 seconde)

; ============================================================================
; WAIT_TICK - Boucle interne : attend que le COUNTFLAG soit mis à 1
; ============================================================================
		; Cette boucle vérifie continuellement le bit COUNTFLAG (bit 16)
		; du registre SYST_CSR. Ce bit passe à 1 quand le compteur SysTick
		; atteint 0, puis est automatiquement effacé quand on lit SYST_CSR.
WAIT_TICK
		; Lire le registre SYST_CSR dans R3
		; IMPORTANT : Cette lecture efface automatiquement le bit COUNTFLAG
        LDR R3, [R0]
		
		; Tester si le bit 16 (COUNTFLAG) est à 1
		; TST fait un AND logique et met à jour les flags sans modifier R3
		; Bit 16 = 0x10000 = (1 << 16)
        TST R3, #(1 << 16)      
		
		; Si COUNTFLAG = 0 (timer pas encore à zéro), reboucler
		; BEQ = Branch if Equal to zero (si le résultat du TST est 0)
        BEQ WAIT_TICK
		
		; Si on arrive ici, COUNTFLAG était à 1, donc 0.1 seconde s'est écoulée
		; Le timer SysTick se recharge automatiquement et recommence à compter

		; ===== Décrémenter le compteur de périodes =====
		; Soustraire 1 de R2 et mettre à jour les flags (SUBS au lieu de SUB)
        SUBS R2, R2, #1
		
		; Si R2 != 0, on n'a pas encore attendu assez de périodes
		; BNE = Branch if Not Equal to zero
        BNE WAIT_SEC
		
		; Si on arrive ici, toutes les périodes sont écoulées (R2 = 0)
		; Durée totale écoulée = ROTATION_TIME x 0.1 seconde

		; ===== ÉTAPE 4 : Arrêter le SysTick Timer =====
		; Écrire 0 dans SYST_CSR pour désactiver le timer
		MOV R1, #0
		STR R1, [R0]

		; Retourner au code appelant
        BX LR

ROTATION_90_GAUCHE
		PUSH {LR}				; Save LR because non-leaf-function
		
		BL MOTEUR_GAUCHE_ARRIERE
		BL MOTEUR_DROIT_AVANT
		BL MOTEUR_GAUCHE_ON
		BL MOTEUR_DROIT_ON

		BL DELAY_90_DEG

		BL MOTEUR_GAUCHE_OFF
		BL MOTEUR_DROIT_OFF
		
		POP {PC}				; Get LR because non-leaf-function

ROTATION_90_DROITE
		PUSH {LR}				; Save LR because non-leaf-function
		
		BL MOTEUR_GAUCHE_AVANT
		BL MOTEUR_DROIT_ARRIERE
		BL MOTEUR_GAUCHE_ON
		BL MOTEUR_DROIT_ON

		BL DELAY_90_DEG

		BL MOTEUR_GAUCHE_OFF
		BL MOTEUR_DROIT_OFF
		
		POP {PC}				; Get LR because non-leaf-function

		nop
		END