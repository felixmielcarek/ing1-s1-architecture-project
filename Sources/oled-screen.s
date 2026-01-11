	;; OLED Screen Driver for LM3S9B92 EvalBot
	;; RIT OLED-RIT-P13701 (96x16 pixels) with SSD1300 controller
	;; Interface: I2C1 (not SPI!)
	
	AREA    |.text|, CODE, READONLY

; =========== OLED CONSTANTS ===========
; I2C1 Module
I2C1_BASE			EQU 0x40021000
I2C1_MSA			EQU 0x40021000	; Master Slave Address
I2C1_MCS			EQU 0x40021004	; Master Control/Status
I2C1_MDR			EQU 0x40021008	; Master Data
I2C1_MTPR			EQU 0x4002100C	; Master Timer Period
I2C1_MCR			EQU 0x40021020	; Master Configuration

; GPIO Port F (Reset pin)
GPIO_PORTF_BASE		EQU 0x40025000
GPIO_PORTF_DIR		EQU 0x40025400
GPIO_PORTF_DEN		EQU 0x4002551C
GPIO_PORTF_DATA		EQU 0x400253FC

; GPIO Port G (I2C1 pins)
GPIO_PORTG_BASE		EQU 0x40026000
GPIO_PORTG_AFSEL	EQU 0x40026420
GPIO_PORTG_DEN		EQU 0x4002651C
GPIO_PORTG_ODR		EQU 0x4002650C	; Open Drain

; OLED Pins
OLED_RST_PIN		EQU 0x01		; PF0 - Reset
; PG0 = I2C1SCL (Clock)
; PG1 = I2C1SDA (Data)

; System Control
SYSCTL_RCGC1		EQU 0x400FE104	; Clock for I2C
SYSCTL_RCGC2		EQU 0x400FE108	; Clock for GPIO

; I2C Address (SSD1300 - essayer 0x3C et 0x3D)
; Note: L'adresse peut être 0x3C ou 0x3D selon la config hardware
OLED_I2C_ADDR		EQU 0x78

; =========== EXPORTED FUNCTIONS ===========
	EXPORT OLED_INIT
	EXPORT OLED_CLEAR
	EXPORT OLED_WRITE_STRING
	EXPORT OLED_SET_CURSOR
	EXPORT OLED_TEST_FILL

; =========== OLED INITIALIZATION ===========
OLED_INIT
	PUSH {LR}
	
	; Enable clock for GPIO Port F, G and I2C1
	LDR R0, =SYSCTL_RCGC2
	LDR R1, [R0]
	ORR R1, R1, #0x60		; Enable Port F (bit 5) and Port G (bit 6)
	STR R1, [R0]
	
	LDR R0, =SYSCTL_RCGC1
	LDR R1, [R0]
	ORR R1, R1, #0x4000		; Enable I2C1 (bit 14)
	STR R1, [R0]
	
	; Delay for clock stabilization
	MOV R2, #50000
delay_init
	SUBS R2, R2, #1
	BNE delay_init
	
	; ========================================================================
	; Configure Port F for Reset (PF0)
	; ========================================================================
	LDR R0, =GPIO_PORTF_DIR
	LDR R1, [R0]
	ORR R1, R1, #0x01		; PF0 as output
	STR R1, [R0]
	
	LDR R0, =GPIO_PORTF_DEN
	LDR R1, [R0]
	ORR R1, R1, #0x01		; Digital enable PF0
	STR R1, [R0]
	
	; ========================================================================
	; Configure Port G for I2C1 (PG0=SCL, PG1=SDA)
	; ========================================================================
	LDR R0, =GPIO_PORTG_AFSEL
	LDR R1, [R0]
	ORR R1, R1, #0x03		; PG0 and PG1 use alternate function (I2C)
	STR R1, [R0]
	
	LDR R0, =GPIO_PORTG_DEN
	LDR R1, [R0]
	ORR R1, R1, #0x03		; Digital enable PG0 and PG1
	STR R1, [R0]
	
	; Configure PG1 (SDA) as open-drain
	LDR R0, =GPIO_PORTG_ODR
	LDR R1, [R0]
	ORR R1, R1, #0x02		; PG1 open-drain
	STR R1, [R0]
	
	; ========================================================================
	; Reset OLED (PF0)
	; ========================================================================
	LDR R0, =GPIO_PORTF_DATA
	MOV R1, #0x00			; RST = 0
	STR R1, [R0]
	
	MOV R2, #50000
delay_reset
	SUBS R2, R2, #1
	BNE delay_reset
	
	MOV R1, #OLED_RST_PIN	; RST = 1
	STR R1, [R0]
	
	MOV R2, #50000
delay_reset2
	SUBS R2, R2, #1
	BNE delay_reset2
	
	; ========================================================================
	; Configure I2C1
	; ========================================================================
	; Disable I2C1 during configuration
	LDR R0, =I2C1_MCR
	MOV R1, #0x00
	STR R1, [R0]
	
	; Set I2C1 timer period (100kHz: TPR = (16MHz / (2*10*100kHz)) - 1 = 7)
	LDR R0, =I2C1_MTPR
	MOV R1, #0x07
	STR R1, [R0]
	
	; Enable I2C1 Master
	LDR R0, =I2C1_MCR
	MOV R1, #0x10			; Master enable
	STR R1, [R0]
	
	; Send initialization commands to OLED
	BL OLED_SEND_INIT_COMMANDS
	
	POP {PC}

; =========== SEND INIT COMMANDS ===========
OLED_SEND_INIT_COMMANDS
	PUSH {LR}
	
	; Séquence d'initialisation simplifiée pour SSD1300
	
	; Display OFF
	MOV R0, #0xAE
	BL OLED_WRITE_COMMAND
	
	; Set multiplex ratio pour 16 lignes
	MOV R0, #0xA8
	BL OLED_WRITE_COMMAND
	MOV R0, #0x0F			; 16 MUX (16 lignes)
	BL OLED_WRITE_COMMAND
	
	; Set display offset
	MOV R0, #0xD3
	BL OLED_WRITE_COMMAND
	MOV R0, #0x00
	BL OLED_WRITE_COMMAND
	
	; Set display start line
	MOV R0, #0x40
	BL OLED_WRITE_COMMAND
	
	; Set segment remap (A0/A1)
	MOV R0, #0xA1			; Segment remap
	BL OLED_WRITE_COMMAND
	
	; Set COM output scan direction
	MOV R0, #0xC8			; Scan from COM[N-1] to COM0
	BL OLED_WRITE_COMMAND
	
	; Set COM pins hardware configuration
	MOV R0, #0xDA
	BL OLED_WRITE_COMMAND
	MOV R0, #0x02			; Alternative COM pin config pour 16 lignes
	BL OLED_WRITE_COMMAND
	
	; Set contrast (brightness)
	MOV R0, #0x81
	BL OLED_WRITE_COMMAND
	MOV R0, #0xFF			; Maximum contrast
	BL OLED_WRITE_COMMAND
	
	; Disable entire display ON
	MOV R0, #0xA4			; Resume to RAM content display
	BL OLED_WRITE_COMMAND
	
	; Set normal display (not inverted)
	MOV R0, #0xA6
	BL OLED_WRITE_COMMAND
	
	; Set display clock divide ratio
	MOV R0, #0xD5
	BL OLED_WRITE_COMMAND
	MOV R0, #0x80			; Default ratio
	BL OLED_WRITE_COMMAND
	
	; Enable charge pump (IMPORTANT pour OLED)
	MOV R0, #0x8D
	BL OLED_WRITE_COMMAND
	MOV R0, #0x14			; Enable charge pump
	BL OLED_WRITE_COMMAND
	
	; Display ON
	MOV R0, #0xAF
	BL OLED_WRITE_COMMAND
	
	; Delay après activation
	MOV R2, #10000
init_delay
	SUBS R2, R2, #1
	BNE init_delay
	
	POP {PC}

; =========== I2C WRITE COMMAND ===========
; R0 = command byte
OLED_WRITE_COMMAND
	PUSH {R4, LR}
	MOV R4, R0
	
	; Set slave address for write
	LDR R0, =I2C1_MSA
    MOV R1, #OLED_I2C_ADDR  ; Pas de shift si adresse déjà à 8 bits
	STR R1, [R0]
	
	; Send control byte (0x00 = Co=0, D/C=0 = command follows)
	LDR R0, =I2C1_MDR
	MOV R1, #0x00
	STR R1, [R0]
	
	; Start + Run (START=1, RUN=1, ACK=0)
	LDR R0, =I2C1_MCS
	MOV R1, #0x03
	STR R1, [R0]
	
	; Wait for completion
	BL I2C_WAIT
	
	; Check for errors
	LDR R0, =I2C1_MCS
	LDR R1, [R0]
	TST R1, #0x02		; Check ERROR bit
	BNE cmd_error		; Si erreur, abandonner
	
	; Send command byte
	LDR R0, =I2C1_MDR
	STR R4, [R0]
	
	; Run + Stop (RUN=1, STOP=1)
	LDR R0, =I2C1_MCS
	MOV R1, #0x05
	STR R1, [R0]
	
	; Wait for completion
	BL I2C_WAIT
	
cmd_error
	POP {R4, PC}

; =========== I2C WRITE DATA ===========
; R0 = data byte
OLED_WRITE_DATA
	PUSH {R4, LR}
	MOV R4, R0
	
	; Set slave address for write
	LDR R0, =I2C1_MSA
	LDR R1, =(OLED_I2C_ADDR << 1)
	STR R1, [R0]
	
	; Send control byte (0x40 = data follows)
	LDR R0, =I2C1_MDR
	MOV R1, #0x40
	STR R1, [R0]
	
	; Start transmission
	LDR R0, =I2C1_MCS
	MOV R1, #0x03
	STR R1, [R0]
	
	BL I2C_WAIT
	
	; Send data byte
	LDR R0, =I2C1_MDR
	STR R4, [R0]
	
	; Send with STOP
	LDR R0, =I2C1_MCS
	MOV R1, #0x05
	STR R1, [R0]
	
	BL I2C_WAIT
	
	POP {R4, PC}

; =========== I2C WAIT ===========
I2C_WAIT
	LDR R0, =I2C1_MCS
wait_loop
	LDR R1, [R0]
	TST R1, #0x01			; Check BUSY bit
	BNE wait_loop
	BX LR

; =========== CLEAR SCREEN ===========
OLED_CLEAR
	PUSH {R4, LR}
	
	MOV R4, #0
clear_loop
	MOV R0, #0x00
	BL OLED_WRITE_DATA
	ADD R4, R4, #1
	CMP R4, #192			; 96x16/8 = 192 bytes (96 colonnes x 2 pages)
	BLT clear_loop
	
	POP {R4, PC}

; =========== TEST FILL (remplir écran avec pixels blancs) ===========
OLED_TEST_FILL
	PUSH {R4, LR}
	
	; Remplir tout l'écran avec 0xFF (tous pixels allumés)
	MOV R4, #0
fill_loop
	MOV R0, #0xFF			; Tous les pixels allumés
	BL OLED_WRITE_DATA
	ADD R4, R4, #1
	CMP R4, #192			; 96x16/8 = 192 bytes
	BLT fill_loop
	
	POP {R4, PC}

; =========== SET CURSOR ===========
; R0 = column (0-95), R1 = page (0-1 pour écran 16 lignes)
OLED_SET_CURSOR
	PUSH {R4, R5, LR}
	MOV R4, R0
	MOV R5, R1
	
	; Set page address (seulement 0-1 pour écran 16 lignes)
	AND R5, R5, #0x01
	ORR R5, R5, #0xB0
	MOV R0, R5
	BL OLED_WRITE_COMMAND
	
	; Set column address (lower nibble)
	AND R0, R4, #0x0F
	BL OLED_WRITE_COMMAND
	
	; Set column address (upper nibble)
	LSR R0, R4, #4
	ORR R0, R0, #0x10
	BL OLED_WRITE_COMMAND
	
	POP {R4, R5, PC}

; =========== WRITE STRING ===========
; R0 = pointer to string
OLED_WRITE_STRING
	PUSH {R4, R5, LR}
	MOV R4, R0
	
write_char_loop
	LDRB R5, [R4], #1
	CMP R5, #0				; Check for null terminator
	BEQ write_string_end
	
	; Write character (simplified - just write ASCII value)
	MOV R0, R5
	BL OLED_WRITE_DATA
	
	B write_char_loop
	
write_string_end
	POP {R4, R5, PC}

; =========== EXAMPLE STRING ===========
	AREA myData, DATA, READONLY
hello_msg 	DCB "EVALBOT", 0
ready_msg	DCB "READY!", 0
finish_msg	DCB "4 ROTATIONS", 0
done_msg	DCB "TERMINE!", 0
	
	EXPORT ready_msg
	EXPORT finish_msg
	EXPORT done_msg
	
	END
