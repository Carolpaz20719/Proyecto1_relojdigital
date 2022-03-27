; Archivo:	Proyecto_1.s
; Dispositivo:	PIC16F887
; Autor:	Carolina Paz 20719
; Compilador:	pic-as (v2.30), MPLABX V5.40
; 
; Programa:	Reloj Digital
; Hardware:	Pic16f887, leds
;
; Creado:	11 de marzo 2022
; Última modificación: 20 de marzo 2022
    
PROCESSOR 16F887
#include <xc.inc>
    
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)

;-----------------MACROS----------------------
restart_tmr0	macro
    ;Timer0 a 10ms
    banksel PORTA               ; cambiamos de banco
    movlw   251	                ; mover literal a w
    movwf   TMR0                ; configura tiempo de retardo (10ms de retardo)
    bcf	    T0IF                ; limpiamos bandera de interrupción
    endm
    
restart_tmr1	macro
    ;Timer1 a 500ms
    movlw   225	                ; mover literal a w
    movwf   TMR1H               ; guardar w en TMR1H
    movlw   123		; mover literal a w
    movwf   TMR1L               ; guardar w en TMR1L
    bcf	    TMR1IF              ; limpiamos bandera de interrupción
    endm
    
divlw	macro	denominator
    ;Prepara el registro para la división
    movwf   var_div		; mover w a var_div
    clrf    var_div+1		; limpiar var_div+1
    ;Realizar la división
    incf    var_div+1		; incrementar var_div+1
    movlw   denominator		; mover literal a w
    subwf   var_div, f		; restar w de f
    btfsc   CARRY               ; revisar la resta
    goto    $-4			; salta 4 lineas
    ;prepara el resultado de la división
    decf    var_div+1, w	; decrementar var_div+1 y guardar en w
    movwf   res_div		; mover w a res_div
    ;preparar el residuo
    movlw   denominator		; mover literal a w
    addwf   var_div, w		; sumar w y f y guardar en w
    movwf   rem_div             ; mover w a rem_div 
    endm
    
;Función para multiplicar por 2 (contador decadas)
multw	macro	mult_reg	
    movf    mult_reg, w		; mover a mult_reg y guardar en w
    addwf   mult_reg, w         ; sumar f + w y guardar en w
    movwf   mult_reg		; mover w a mult_reg
    endm
    
;Función para mover literal a un registro
movlf	macro	literal, registro
    movlw   literal		; mover literal a w
    movwf   registro		; mover w a registro
    endm
    
;Función para mover registro a otro
movftf	macro	partida, destino
    movf    partida, w		; mover a partida y guardar en w
    movwf   destino		; mover w a destino
    endm
    
;Función para comparar una literal con un registro
complf	macro	literal, registro
    movf    registro, w		; mover a registro y guardar en w
    sublw   literal		; restar literal a w
    endm
    
;Función parar comparar registros
compff	macro	l_reg, s_reg
    movf    s_reg, w		; mover a s_seg y guardar en w
    subwf   l_reg		; restar w a l_reg
    endm
    
;Función para separar las variables en unidades y decenas
sepnib	macro	registro
    ;Divisón Primer Display (Minutos)
    movf    registro,w	        ; mover variable minutos a w
    divlw   10		        ; llamar la divisón por 10
    movf    res_div, w	        ; guardar la respuesta en w
    movwf   nibbles+1	        ; mover a nibble decena
    movf    rem_div, w	        ; guardar el remanente en w
    movwf   nibbles	        ; mover a nibble de unidades
    ;División Segundo Display  (Horas)
    movf    registro+1,w        ; mover vairable horas a w
    divlw   10		        ; llamar la divisón por 10
    movf    res_div, w	        ; guardar la respuesta en w
    movwf   nibbles+3	        ; mover a nibble decena
    movf    rem_div, w	        ; guardar el remanente en w
    movwf   nibbles+2	        ; mover a nibble de unidades
    endm
  
;----------------------VARIABLES--------------------
PSECT udata_bank0
    ; Variables Generales
    estados:	    DS	1       ; variable de estados
    
    ; Variables para el conteo del tiempo
    contador:	    DS  1       ; bandera para contar segundos
    tiempo:	    DS	3       ; contadores de seg, min y hrs
    tiempo_ban:	    DS	1       ; bandera para incrementar el tiempo
    tiempo_temp:    DS	2       ; registros temporales para inc y dec la hora
    
    ; Variables para el conteo de la fecha
    fecha:	    DS  2       ; contadores de dia y mes
    fecha_temp:	    DS	2       ; registros temporales para inc y dec la fecha
    mes_temp:	    DS	1       ; guardar número de días en el mes
    
    ; Variables para nviar valores a los displays
    nibbles:	    DS	4       ; Variables para separación en nibbles
    displays:	    DS	4       ; Variables para almacenar valores que van al display
    mux:	    DS	1       ; Multiplexado de transistores
    
    ; Variables del Timer
    timer:	    DS	2       ; Varibles para almacenar minutos y segundos del timer
    timer_estados:  DS	1       ; Variable para almacenar el subestado activo del timer
    timer_ban:	    DS	1       ; Banderas para indicar segundos al timer
    timer_contador: DS	1       ; Contador para apagar la alrma del timer automáticamente
    
    ; Variables del macro de división
    var_div:	    DS  2       ; variable de división
    res_div:	    DS  1       ; resultado para la división
    rem_div:	    DS  1       ; residuo de la división
    
    ; Definición de Puerto B
    MODO    EQU	    0		; variable para el MODO
    INC1    EQU	    1           ; variable de incrementar 1
    DEC1    EQU	    2           ; variable de decrementar 1
    INC2    EQU	    3		; variable de incrementar 2
    DEC2    EQU	    4		; variable de decrementar 2
    
PSECT udata_shr
    ; Memoria temporal
    W_TEMP:	    DS	1       ; memoria temporal para w
    STATUS_TEMP:    DS	1       ; memoria temporal para STATUS
 
;-----------------VECTOR RESET-------------------------
PSECT resVect, class=CODE, abs, delta=2
ORG 00h     ; posición 0000h para el reset
resetVec:
    PAGESEL main
    goto    main

;-----------------VECTOR INTERRUPCIONES-----------------
PSECT intVect, class=CODE, abs, delta=2
ORG 04h	    ;posición 0004h para las interrupciones
push:
    movwf   W_TEMP              ; Guardamos W
    swapf   STATUS, W
    movwf   STATUS_TEMP         ; Guardamos STATUS
isr:
    btfsc   TMR0IF              ; Verificamos bandera del TMR0
    call    int_tmr0            ; Llamar a su subrutina de interrupción correspondiente
    
    btfsc   TMR1IF              ; Verificamos bandera del TMR1
    call    int_tmr1            ; Llamar a su subrutina de interrupción correspondiente
pop:
    swapf   STATUS_TEMP, W
    movwf   STATUS              ; Recuperamos el valor de reg STATUS
    swapf   W_TEMP, F            
    swapf   W_TEMP, W           ; Recuperamos valor de W
    retfie                      ; Regresamos a ciclo principal
   
;-------------SUBRUTINAS DE INTERRUPCIONES--------
    
;------------------TIMER 0------------------------
int_tmr0:
    restart_tmr0		; Reiniciar timer 0
    multw   mux			; Multiplicar por 2 a mux
    btfsc   mux, 4		; Revisar el bit 4
    movlf   1, mux		; Si es 1, mover 1 a mux
    ;mover el multiplexado al PORTD
    movftf  mux, PORTD		; Si es 0, mover mux al puerto D
    ;mandar variables de display a los displays
    call    mostrar_displays	; llamar a mostrar displays
    return
    
;------------------TIMER 1------------------------
int_tmr1:
    restart_tmr1		; Reiniciar timer 1
    incf    contador		; Incrementar a contador
    btfsc   contador, 0		; Revisar el bit 0
    goto    tiempo_completo	; si es 1, se contó un segundo
    goto    tiempo_medio        ; si es 0, no se ha contado un segundo
    
tiempo_completo:
    bsf	    PORTB, 7		; encender luz intermitente
    bsf	    tiempo_ban, 0	; encender bandera de incremento del reloj
    btfsc   timer_estados, 1    ; si se está en el estado del timer auto
    bsf	    timer_ban, 0	; encender bandera de decremento del timer
    btfsc   timer_estados, 2	; se se está en el estado de alarma
    bsf	    timer_ban, 1	; encender bandera de incremento del contador del timer
    return
    
tiempo_medio:
    bcf	    PORTB, 7		; apagar luz intermitente
    return

PSECT code, delta=2, abs
ORG 100h		        ; posición 100h para el codigo
 
;--------------------TABLAS-----------------------
tabla_catodo:
    clrf   PCLATH
    bsf    PCLATH, 0   
    andlw  0x0f        
    addwf  PCL         
    retlw  00111111B   ;0
    retlw  00000110B   ;1
    retlw  01011011B   ;2
    retlw  01001111B   ;3
    retlw  01100110B   ;4
    retlw  01101101B   ;5
    retlw  01111101B   ;6
    retlw  00000111B   ;7
    retlw  01111111B   ;8
    retlw  01101111B   ;9
 
/*tabla_catodo:
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0f
    addwf   PCL
    retlw   11000000B	;0
    retlw   11111001B	;1
    retlw   10100100B	;2
    retlw   10110000B	;3
    retlw   10011001B	;4
    retlw   10010010B	;5
    retlw   10000010B	;6
    retlw   11111000B	;7
    retlw   10000000B	;8
    retlw   10010000B	;9*/
    
tabla_dias:
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0f
    addwf   PCL
    retlw   0	    ;sirve como espaciador
    retlw   31	    ;enero
    retlw   28	    ;febrero
    retlw   31	    ;marzo
    retlw   30	    ;abril
    retlw   31	    ;mayo
    retlw   30	    ;junio
    retlw   31	    ;julio
    retlw   31	    ;agosto
    retlw   30	    ;septiembre
    retlw   31	    ;octubre
    retlw   30	    ;noviembre
    retlw   31	    ;diciembre 
 
;-----------------CONFIGURACION----------------------
main:
    ;Interrupciones de Configuración
    call    config_io		; configuración de I/O
    call    config_clk          ; configuracion del reloj
    call    config_tmr0		; configuracion del Timer 0
    call    config_tmr1		; configuracion del Timer 1
    call    config_int		; configuracion de las interrupciones
    call    limpiar_var		; configuracion para limpiar variables
    
;------------------LOOP----------------------------
loop:
    ;enviar registro de estados al PORTA
    movftf  estados, PORTA	; mover estados a puerto A
    
    ;función para cambiar estados
    btfss   PORTB, MODO		; revisar el boton de MODO (ver si esta presionado)
    call    btn_accion		; llamar btn_accion
    
    ;función para incrementar el tiempo
    call    inc_seg		; llamar a incrementar segundos
    
    ;convertir nibbles a bytes de displays
    call    preparar_displays	; llamar a preprar los displays
    
    ;realizar el conteo decreciente del timer
    btfsc   timer_estados, 1	; revisar el bit 1 del timer_estados
    call    timer_auto          ; llamar a timer_auto
    
    ;conteo automático de la alarma del timer
    btfsc   timer_estados, 2    ; revisar el bit 2 del timer_estados
    call    timer_cont		; llamar al timer_cont
    
    ;selección de estado actual
    btfsc   estados, 0		; revisar el bit 0
    goto    estado0		; si es 1, ir a estado0
    btfsc   estados, 1		; revisar el bit 1
    goto    estado1		; si es 1, ir al estado1
    btfsc   estados, 2		; revisar el bit 2
    goto    estado2		; si es 1, ir al estado2
    btfsc   estados, 3		; revisar el bit 3
    goto    estado3		; si es 1, ir al estado3
    btfsc   estados, 4		; revisar el bit 4
    goto    estado4		; si es 1, ir al estado4
    goto    loop		; regresar a loop
    
;Estado de la hora con incremento automático
estado0:
    sepnib  tiempo+1	        ; Setear los Nibbles del tiempo automático
    btfsc   timer_estados, 0	; revisar bit 0, del timer_estados
    call    llamar_estado2      ; llamar a estado2 (del timer)
    goto    loop		; regresar a loop
    
;Estado de configurar la hora
estado1:
    sepnib  tiempo_temp  	; separar horas de los minutos
    btfss   PORTB, INC2		; revisar si el boton esta presionado
    call    inc_min_dis		; si lo esta, llamar a inc_min_dis	
    btfss   PORTB, DEC2         ; revisar si el boton esta presionado
    call    dec_min_dis		; si lo esta, llamar a dec_min_dis
    btfss   PORTB, INC1		; revisar si el boton esta presionado
    call    inc_hora_dis	; si lo esta, llamar a inc_hora_dis
    btfss   PORTB, DEC1		; revisar si el boton esta presionado
    call    dec_hora_dis	; si lo esta, llamar a dec_hora_dis
    goto    loop		; regresar a loop
    
;Estado de la fecha con incremento automático
estado2:
    sepnib  fecha		; separar los dias de los meses
    goto    loop		; regresar a loop
    
;Estado de configurar la fecha
estado3:
    sepnib  fecha_temp		; separar los dias de los meses
    btfss   PORTB, INC2		; revisarsi el boton esta presionado
    call    inc_dia_dis		; si lo esta, llamar a inc_dia_dis	
    btfss   PORTB, DEC2		; revisar si el boton esta presionado
    call    dec_dia_dis		; si lo esta, llamar a dec_dia_dis
    btfss   PORTB, INC1		; revisar si el boton esta presionado
    call    inc_mes_dis		; si lo esta, llamar a inc_mes_dis
    btfss   PORTB, DEC1		; revisar si el boton esta presionado
    call    dec_mes_dis		; si lo esta, llamar a dec_mes_dis
    goto    loop                ; regresar a loop
    
;Estado del timer
estado4:
    sepnib  timer		; Separar minutos de segundos
    btfsc   timer_estados, 0	; revisar el bit 0 del timer
    goto    timer_estado1	; si es 1, ir a estado1 del timer
    btfsc   timer_estados, 1    ; revisar el bit 1 del timer
    goto    timer_estado2       ; si es 1, ir a estado2 del timer
    btfsc   timer_estados, 2    ; revisar el bit 2 del timer
    goto    timer_estado3	; si es 1, ir a estado3 del timer
    goto    timer_estado0	; ir al estado0 del timer
    
;Sub-Estados del timer
timer_estado0:			; estado de no hacer nada
    btfss   PORTB, INC1		; revisar si el boton esta presionado
    call    llamar_estado1	; si lo esta, llamar a estado 1
    btfss   PORTB, DEC1		; revisar si el boton esta presionado
    call    llamar_estado1	; si lo esta, llamar a estado 1
    btfss   PORTB, INC2		; revisar si el boton esta presionado
    call    llamar_estado1	; si lo esta, llamar a estado 1
    btfss   PORTB, DEC2		; revisar si el boton esta presionado
    call    llamar_estado1	; si lo esta, llamar a estado 1
    goto    loop		; regresar a loop
    
timer_estado1:		        ; estado de configurar el timer
    btfss   PORTB, INC2		; revisar si el boton esta presionado
    call    inc_timer_seg	; si lo esta, llamar inc_timer_seg
    btfss   PORTB, DEC2		; revisar si el boton esta presionado
    call    dec_timer_seg	; si lo esta, llamar dec_timer_seg
    btfss   PORTB, INC1		; revisar si el boton esta presionado
    call    inc_timer_min	; si lo esta, llamar inc_timer_min
    btfss   PORTB, DEC1		; revisar si el boton esta presionado
    call    dec_timer_min	; si lo esta, llamar dec_timer_min
    goto    loop		; regresar a loop
    
timer_estado2:			; estado de conteo regresivo
    goto    loop                ; regresar a loop
    
timer_estado3:		        ; estado de alarma
    bsf	    PORTB, 6		; encender la luz de la alarma
    goto    loop		; regresar a loop
    
;------------------SUBRUTINAS-------------------------------
config_io:
    ;Puertos como digitales
    banksel ANSEL		; Cambiar de Banco
    clrf    ANSEL		; Poner I/O digitales
    clrf    ANSELH
    
    ;Entradas-Salidas
    banksel TRISA		; Cambiar de Banco
    clrf    TRISA		; salidas de LEDs
    bsf	    TRISB, 0		; incrementar el display 1
    bsf	    TRISB, 1		; decrementar el display 1
    bsf	    TRISB, 2		; incrementar el display 2
    bsf	    TRISB, 3		; decrementar el display 2
    bsf	    TRISB, 4		; modo
    bcf	    TRISB, 6		; luz de alarma
    bcf	    TRISB, 7		; luz intermitente
    clrf    TRISC		; salidas a displays
    clrf    TRISD		; salidas a transistores
    
    ;Habilitación de Weak Pull-ups
    bcf	    OPTION_REG, 7	; Cambiar de Banco
    bsf	    WPUB, 0
    bsf	    WPUB, 1
    bsf	    WPUB, 2
    bsf	    WPUB, 3
    bsf	    WPUB, 4
    
    //Limpiar puertos
    banksel PORTA		; Cambiar de Banco
    clrf    PORTA		; Limpiar PORTA
    clrf    PORTB		; Limpiar PORTB
    clrf    PORTC		; Limpiar PORTC
    clrf    PORTD		; Limpiar PORTD
    return
    
config_clk:
    banksel OSCCON		; cambiamos de  banco 
    bcf	    IRCF2               ; IRCF2  0
    bsf	    IRCF1		; IRCF1  1
    bcf	    IRCF0		; IRCF0  0 --> 010 250kHz
    bsf	    SCS			; SCS =1, Usamos reloj interno
    return
    
config_tmr0:
    banksel TRISA		; cambiamos de  banco 
    bcf	    T0CS		; Timer0 como temporizador
    bcf	    PSA			; Prescaler a TIMER0
    bsf	    PS2			; PS2
    bsf	    PS1			; PS1
    bcf	    PS0			; PS0 Prescaler de 1 : 128
    restart_tmr0		; reinicar el timer 0
    return
    
config_tmr1:
    banksel PORTA		; Cambiamos a banco 00
    bcf	    TMR1GE		; TMR1 siempre contando
    bcf	    T1CKPS1		; Prescaler 1:4
    bsf	    T1CKPS0
    bcf	    T1OSCEN		; Apagamos LP
    bcf	    TMR1CS		; Reloj interno
    bsf	    TMR1ON		; Encendemos TMR1
    restart_tmr1		; 500 ms
    return
    
config_int:
    banksel TRISA		; cambiar de banco
    bsf	    TMR1IE		; interrupción TMR1
    banksel PORTA		; cambiar de banco
    bsf	    GIE			; interrupciones globales
    bsf	    PEIE		; interrupciones periféricas
    bsf	    T0IE		; interrupción TMR0
    bcf	    T0IF		; limpiar bandera TMR0
    bcf	    TMR1IF		; limpiar bandera TMR1
    return
    
limpiar_var:
    clrf    tiempo		; limpiar tiempo
    clrf    tiempo+1		; limpiar tiempo+1
    clrf    tiempo+2		; limpiar tiempo+2
    movlf   1, mux		; mover literal 1 a mux
    movlf   1, estados		; mover literal 1 a estados
    movlf   1, fecha		; mover literal 1 a fecha
    movlf   1, fecha+1		; mover literal 1 a fecha+1
    clrf    timer		; limpiar timer
    clrf    timer+1		; limpiar timer+1
    clrf    timer_estados	; limpiar timer_estados
    return
    
;------------------SUBRUTINAS-ACCION--------------------
    
;Acciones del Botón de Modo
btn_accion:
    btfss   PORTB, MODO		; revisar el boton de MODO
    goto    $-1			; si es 0, regresar 1 linea
    multw   estados		; multiplicar a estados por 2
    btfss   estados, 5		; revisar bit 5 de estados
    goto    $+3			; si es 0, ir a 3 lineas adelante
    movlf   1, estados		; si es 1; mover literal de 1 a estados 
    btfsc   estados, 1		; revisar bit 1 de estados 
    call    empezar_config_hora	; si es 1, llamar a empezar_config_hora
    btfsc   estados, 2		; revisar bit 2 de estados 
    call    terminar_config_hora; si es 1, llamar a terminar_config_hora
    btfsc   estados, 3		; revisar bit 3 de estados 
    call    empezar_config_fecha; si es 1, llamar empezar_config_fecha
    btfss   estados, 4		; revisar el bit 4 de estados
    goto    $+4			; si es 0, ir 4 lineas adelante
    call    terminar_config_fecha; llamar a terminar_config_fech
    btfsc   timer_estados, 2	; revisar el bit 2 del timer_estados
    call    llamar_estado0	; si es 1, llamar a llamar_estado0
    return
    
;Función para preparar las varaibles de displays
preparar_displays:
    ;Mandar a Displays Unidades de Minutos
    movf    nibbles, w		; mover a niblles y guardar en w
    call    tabla_catodo	; llamar a tabla
    movwf   displays		; mover w a displays
    ;Mandar a Displays Decenas de Minutos
    movf    nibbles+1, w	; mover a nibbles+1 y guardar en w
    call    tabla_catodo	; llamar a tabla
    movwf   displays+1		; mover	 w a displays+1
    ;Mandar a Displays Unidades de Horas
    movf    nibbles+2, w	; mover a nibbles+2 y guardar en w
    call    tabla_catodo	; llamar a tabla
    movwf   displays+2		; mover	 w a displays+2
    ;Mandar a Displays Decenas de Minutos
    movf    nibbles+3, w	; mover a nibbles+1 y guardar en w
    call    tabla_catodo	; llamar a tabla
    movwf   displays+3		; mover	 w a displays+3
    return
    
;mostrar variables de display en el PORTC
mostrar_displays:
    btfsc   mux, 0		; revisar bit 0 de mux
    movftf  displays+3, PORTC	; si es 1, mover displays+3 a puerto C
    btfsc   mux, 1		; revisar bit 1 de mux
    movftf  displays+2, PORTC	; si es 1, mover displays+2 a puerto C
    btfsc   mux, 2		; revisar bit 2 de mux
    movftf  displays+1, PORTC	; si es 1, mover displays+1 a puerto C
    btfsc   mux, 3		; revisar bit 3 de mux
    movftf  displays, PORTC	; si es 1, mover displays a puerto C
    return   
    
;-------------------ESTADOS ------------------------
    
;-------------------ESTADO 0------------------------
;Conteo normal del reloj  
inc_seg:
    btfss   tiempo_ban, 0	; revisar el bit 0 de tiempo_ban
    return			; regresar
    incf    tiempo		; si es 1, incrementar variable tiempo
    complf   60, tiempo		; comparar literal con tiempo
    btfsc   STATUS, 2		; revisar la resta
    call    inc_min		; si es 1, llamar a inc_min
    bcf	    tiempo_ban, 0	; 
    return
    
inc_min:
    clrf    tiempo		; limpiar a tiempo
    incf    tiempo+1		; incrementar a tiempo+1
    complf  60, tiempo+1	; comparar la literal con tiempo+1
    btfsc   STATUS, 2		; revisar la resta
    call    inc_hora		; si es 1, llamar a inc_hora
    return			; regresar
    
inc_hora:
    clrf    tiempo+1		; limpiar a tiempo+1
    incf    tiempo+2		; incrementar a tiempo+2
    complf  24, tiempo+2	; comparar la literal con tiempo+2
    btfsc   STATUS, 2		; revisar la resta
    call    inc_dia		; si es 1, llamar a inc_dia
    return			; regresar
    
inc_dia:
    clrf    tiempo+2		; limpiar a tiempo+2
    movf    fecha+1, w		; mover fecha+1 a w
    call    tabla_dias		; llamar a tabla_dias
    movwf   mes_temp		; mover el valor de w a mes_temp
    compff  mes_temp, fecha	; comparar el mes_temp con fecha
    btfss   STATUS, 2		; revisar la resta
    goto    $+3			; si es 0, ir 3 lineas adelante
    call    inc_mes		; si es 1, llamar la inc_mes
    return			; regresar
    incf    fecha		; incrementar fecha
    return			; regresar
    
inc_mes: 
    movlf   1, fecha		; mover la literal a fecha
    incf    fecha+1		; incremetar a fecha+1
    complf  13, fecha+1		; comparar litral con fecha+1
    btfss   STATUS, 2		; revisar la resta
    return			; Si es 0, regresar
    movlf   1, fecha+1		; Si es 1, mover literal de 1 a fecha+1
    return			; regresar
    
;------------------ESTADO 1 ----------------
;Configurar la hora

empezar_config_hora:
    movftf  tiempo+1, tiempo_temp   ; guardar el valor de tiempo+1 en tiempo_temp
    movftf  tiempo+2, tiempo_temp+1 ; guardar el valor de tiempo+2 en tiempo_temp+1
    return
    
//Setear el reloj
inc_min_dis:
    btfss   PORTB, INC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    incf    tiempo_temp		; si ya no lo esta, incrementar tiempo_temp
    complf  60, tiempo_temp	; comparar literal de 60 con tiempo_temp
    btfsc   STATUS, 2		; revisar la resta
    clrf    tiempo_temp		; si es 1, limpiar a tiempo_temp
    return			; regresar
    
dec_min_dis:
    btfss   PORTB, DEC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    tiempo_temp		; si ya no lo esta, decrementar tiempo_temp
    complf  255, tiempo_temp	; comparar literal de 255 con tiempo_temp
    btfss   STATUS, 2		; revisar la resta
    return			; si es 0, regresar
    movlf   59, tiempo_temp	; si es 1, mover la litral de 59 a tiempo_temp
    return			; regresar
    
inc_hora_dis:
    btfss   PORTB, INC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    incf    tiempo_temp+1	; si ya no lo esta, imcrementar tiempo_temp+1
    complf   24, tiempo_temp+1	; comparar literal de 24 con tiempo_temp+1
    btfsc   STATUS, 2		; revisar la resta
    clrf    tiempo_temp+1	; si es 1, limpiar tiempo_temp+1
    return			; regresar
    
dec_hora_dis:
    btfss   PORTB, DEC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    tiempo_temp+1	; si ya no lo esta, decrementar tiempo_temp+1
    complf  255, tiempo_temp+1	; comparar literal de 255 con tiempo_temp
    btfss   STATUS, 2		; revisar la resta
    return			; si es 0, regresar
    movlf   23, tiempo_temp+1	; si es 1, mover litral de 23 a tiempo_temp+1
    return			; regresar
    
;-------------------ESTADO 2 --------------------------
;Conteo normal de la fecha

terminar_config_hora:
    movftf  tiempo_temp, tiempo+1   ; colocar los valores de la configuración en tiempo+1
    movftf  tiempo_temp+1, tiempo+2 ; colocar los valores de la configuración en tiempo+2
    return
    
;--------------------ESTADO 3 --------------------------
;Configurar la fecha
empezar_config_fecha:
    movftf  fecha, fecha_temp	    ; guardar el valor de fecha en fecha_temp
    movftf  fecha+1, fecha_temp+1   ; guardar el valor de fecha+1 en fecha_temp+1
    return
    
inc_dia_dis:
    btfss   PORTB, INC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    movf    fecha_temp+1, w	; si ya no lo esta, mover fecha_temp+1 a w
    call    tabla_dias		; llamar a tabla_dias
    movwf   mes_temp		; mover w a mes_temp
    compff  mes_temp, fecha_temp; comparar los dos registros
    btfsc   STATUS, 2		; revisar la resta
    goto    $+3			; si es 1, ir 3 lineas adelante
    incf    fecha_temp		; si es 0, incrementar  a fecha_temp
    return			; regresar
    movlf   1, fecha_temp	; mover literal de 1 a fecha_temp
    return			; regresar
    
dec_dia_dis:
    btfss   PORTB, DEC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    fecha_temp		; si ya no lo esta, decrementar a fecha_temp
    movlw   0			; mover litral de 0 a w
    subwf   fecha_temp		; restar w a fecha_temp
    btfss   STATUS, 2		; revisar la resta
    return			; si es 0, regresar
    movf    fecha_temp+1, w	; si es1 1, mover fecha_temp a w
    call    tabla_dias		; llamar a tabla dias
    movwf   fecha_temp		; mover w a fecha_temp
    return			; regresar
    
inc_mes_dis:
    btfss   PORTB, INC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    incf    fecha_temp+1	; si ya no lo esta, incrementar fecha+1
    complf  13, fecha_temp+1	; comparar literal de 13 con fecha+1
    btfss   STATUS, 2		; revisar la resta
    goto    $+3			; si es 0, ir 3 lineas adelante
    movlf   1, fecha_temp+1	; si es 1, mover literal de 1 a fecha+1
    movlf   1, fecha_temp       ; si es 1, mover literal de 1 a fecha
    return			; regresar
    
dec_mes_dis:
    btfss   PORTB, DEC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    fecha_temp+1	; si ya no lo esta, decrementar a fecha_temp+1
    movlf   1, fecha_temp	; mover la literal de 1 a fecha_temp
    movlw   0			; mover litral de 0 a w
    subwf   fecha_temp+1	; restar w a fecha_temp+1
    btfss   STATUS, 2		; revisar la resta
    return			; regresar
    movlf   12,fecha_temp+1	; mover literal de 12 a fecha_temp+1
    return			; regresar
    
;-------------------ESTADO 4 ------------------
;Timer
    
;Mover los valores de fecha temporal a los contadores automáticos.
terminar_config_fecha:
    movftf  fecha_temp, fecha	    ; colocar los valores de la configuración en fecha
    movftf  fecha_temp+1, fecha+1   ; colocar los valores de la configuración en fecha+1
    return
    
llamar_estado0:
    movlf   0, timer_estados	; apagar todos los bits de timer_estados
    bcf	    PORTB, 6		; apagar alarma
    return			; regresar
    
llamar_estado1:
    movlf   1, timer_estados	; encender el bit0 de timer_estados
    return			; regresar
    
llamar_estado2:
    movlf   2, timer_estados	; encender el bit1 de timer_estados
    return			; regresar
    
llamar_estado3:
    movlf   4, timer_estados	; encender el bit2 de timer_estados
    clrf    timer		; limpiar timer
    clrf    timer+1		; limpiar el timer 1
    bsf	    PORTB, 6		; encender alarma
    return			; regresar
    
//Incremento y Decremento de la configuración del timer
inc_timer_seg:	
    btfss   PORTB, INC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    incf    timer		; si ya no lo esta, incrementar el timer
    complf  60, timer		; comparar 60 con timer
    btfsc   STATUS, 2		; revisar la resta
    clrf    timer		; si es 1, limpiar el timer
    return			; si es 0, regresar
				
dec_timer_seg:
    btfss   PORTB, DEC2		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    timer		; si ya no lo esta, decrementar el timer
    complf  255, timer		; comparar 255 con timer
    btfss   STATUS, 2		; revisar la resta
    return			; si es 0, regresar
    movlf   59, timer		; si es 1 mover la literal de 59 a timer
    return			; regresar
    
inc_timer_min:
    btfss   PORTB, INC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    incf    timer+1		; si ya no lo esta, incrementar el timer+1
    complf  100, timer+1	; comparar 100 con timer
    btfsc   STATUS, 2		; revisar la resta
    clrf    timer+1		; si es 1, limpiar a timer+1
    return			; si es 0, regresar
				
dec_timer_min:
    btfss   PORTB, DEC1		; revisar si el boton ya no esta presionado (Antirebote)
    goto    $-1			; si lo esta, regresar 1 linea
    decf    timer+1		; si ya no lo esta, decrementar el timer+1
    complf  255, timer+1	; comparar 255 con timer+1
    btfss   STATUS, 2		; revisar la resta
    return			; si es 0, regresar
    movlf   99, timer+1		; si es 1 mover la literal de 99 a timer
    return			; regresar
    
//conteo automático del timer
timer_auto:
    btfss   timer_ban, 0	; si la bandera de decrementar timer está prendida, seguir
    return			; si no está prendida, regresar
    decf    timer		; decrementar los segundos
    complf  255, timer		; ver si se desbordan los segundos
    btfss   STATUS, 2		; revisar la resta
    goto    $+4			; si no se desbordan, limpiar bandera del timerr y regresar
    movlw   59			; si se desborda, mover el valor inicial a los segundos
    movwf   timer		; mover w al timer
    call    timer_auto_min      ; llamar al decremento de minutos
    bcf	    timer_ban, 0        ; indicar que ya se realizó el decremento
    return
    
timer_auto_min:
    decf    timer+1		; decrementar minutos
    complf  255, timer+1        ; ver si se desbordaron los minutos
    btfsc   STATUS, 2		; revisar l resta
    call    llamar_estado3	; si es 1, entrar en estado alarma
    return			; si es 0, regresar
    
;Conteo automático del timer cuando este termina y no es apagado manualmente
timer_cont:
    btfss   timer_ban, 1        ; si la bandera está encendida, realizar el decremento
    return		        ; si es 0, regresar
    incf    timer_contador	; si es 1, incrementar el timer_contador
    complf  60, timer_contador	; comparar literal de 60 con timer_contador
    btfss   STATUS, 2		; revisar la resta
    goto    $+3			; si es 0, ir 3 lineas adelante
    call    llamar_estado0	; si es 1, llamar a llamar_estado0
    clrf    timer_contador	; limpiar a timer_ contador
    bcf	    timer_ban, 1	; apagar la bandera timer_ban
    return
END