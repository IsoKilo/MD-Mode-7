; ====================================================================================================
; Mode7.asm (Version 3)
; Mario Kart/F-Zero styled floor renderer for the Mega Drive.
; 15/03/2026
; Rachel Harrison.
; ====================================================================================================

; Notes:
; This mode 7 function works by pre-calculating the projection view of the screen as several tables.
; The table is selected based on the camera's yaw, so each table represents a rotation.
; But to avoid a ROM that's 99% projection tables, only a quarter rotation's worth of tables are stored and quadrants are handled in code.
; To further reduce the amount of projection tables, angles are limited to 6 degree steps.
; To reduce the amount of pixels drawn, the function renders at an internal resolution of 128x56,
; using double wide pixels to reduce the amount of calculations needed to draw the bitmap.
; This comes with the downside of needing much larger map data, requiring 256kb for a 512x512 map.
; This brings the advantage of colour mixing with dithering by using the upper nybble of a map pixel as a dither pixel,
; bumping the map colour range from 16 to 256, matching the SNES.

; Externally you are expected to:
; Enable the SSF2 ROM mapper.
; Set the resolution to 256x224.
; Load a tilemap of unique tiles to represent the bitmap to the screen.
; Manage the ROM banks the map data is read from. This can be done by setting mapper bank 7 to 7+(mapID/2).
; Manage which 256kb half of the ROM bank should be used with map_useupper to read map data.
; Re-enable interrupts after the function has ran.
; DMA the tiles from bitmap_tiles into VRAM.
; Stretch the mode 7 plane vertically during HBlank to double the height.

; Also I haven't tested this yet so :p
; Check back in later when I do test it!

; Constants
MAP_SIZE: = 512
MAP_ROM_LOWER: = $380000
MAP_ROM_UPPER: = $3C0000
MODE7_WIDTH: = 128
MODE7_HEIGHT: = 56

; Variables
; bitmap_tiles.b    - Bitmap graphics buffer, to be DMA'd at VBlank when finished. 7168 bytes.
; camera_x.w        - Camera info.
; camera_y.w
; camera_yaw.w
; map_useupper.b	- Flag to use the upper 256kb of ROM bank for map data.

Mode7_DrawFloor:
		move    #$2700,sr                               ; Disable interrupts. This is a long task so we don't want to be disturbed.
		lea		(bitmap_tiles_end-1),a0                 ; We start from the end of the buffer to take advantage of using the drbanch register as a pixel count.
		move.w	(camera_x).w,d5                         ; Cache camera position, it's faster to read from a data register rather than RAM.
		move.w	(camera_y).w,d6
		move.w	(camera_yaw).w,d1
        move.l  #MAP_ROM_LOWER,d7                       ; Cache the base address of the map in it's 512kb ROM bank.
        tst.b   (map_useupper).w                        ; We can fit 2 512x512 maps in a 512kb ROM bank, check if we should use the upper one. 
        beq.s   @lower                                  ; If not, use the first map.
        move.l  #MAP_ROM_UPPER,d7                       ; Load map in the upper half of the ROM bank.
@lower:
		move.w	d1,d2								    ; Copy yaw.
		asr.w	#4,d1								    ; Get the 90 degree quadrant the camera is facing.
		andi.w	#15,d2								    ; Get the finer 1/16th angle of the yaw. This gives us a total of 64 angles to face. Smooth enough.
		asl.w	#2,d2								    ; Multiply by long.
		movea.l	ProjectionTableTables(pc,d2.w),a2		; Load corresponding projection table.
		move.w	#(MODE7_WIDTH*MODE7_HEIGHT)-1, d0	    ; Set loop count.

; 0 - 90 Degree draw loop.

Mode7_0DegDraw:
		subi.b	#1,d1							    	; Are we in the 0-90 range?
		bpl.s	Mode7_90DegDraw						    ; If not, check next range.
@loop:
		move.w	d6,d2
		add.w	-(a2),d2							    ; Map Y = Camera Y + Projection Y Off.
		move.w	d5,d1
		add.w	-(a2),d1							    ; Map X = Camera X + Projection X Off.
		tst.w	d1									    ; Has the camera X gone off the left of the map?
		bmi.s	@outofbounds                            ; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d1                            ; Has the camera X gone off the right of the map?
		bge.s	@outofbounds                            ; If so, draw out of bounds.
		tst.w	d2                                      ; Has the camera Y gone off the top of the map?
		bmi.s	@outofbounds                            ; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d2                            ; Has the camera Y gone off the bottom of the map?
		bge.s	@outofbounds                            ; If so, draw out of bounds.
		asl.w	#9,d2								    ; Multiply by 512 to get row index.
		add.w	d2,d1								    ; Create final offset.
        move.l  d7,a1                                   ; Load fixed map ROM bank.
		add.l	d1,a1								    ; Go to corresponding byte in map data.
		move.b	(a1),d3								    ; Get the pixel.
		beq.s	@outofbounds						    ; If it's 0, just draw 0.
		move.b	d3,d4
		andi.b	#$F0,d4								    ; Is this a dither pixel?
		bne.s	@draw								    ; If so just send the raw map data as a pixel.
		asl.b	#4,d4								    ; Shift back flat colour into upper nybble.
		or.b	d4,d3								    ; Merge to form wide pixel.
@draw:
		move.b	d3,-(a0)							    ; Write 2 pixels to bitmap buffer.
		dbf		d0,@loop							    ; Loop until bitmap is fully drawn.
		rts

@outofbounds:
		move.b	#0,-(a0)							    ; Write 0 to bitmap.
		dbf		d0,@loop							    ; Loop until bitmap is fully drawn.
		rts

; 90 - 180 Degree draw loop.

Mode7_90DegDraw:
		subi.b	#1,d1								    ; Are we in the 90-180 range?
		bpl.s	Mode7_180DegDraw					    ; If not, check next range.
@loop:
		move.w	d5,d1
		sub.w	-(a2),d1							    ; Map X = Camera X - Projection Y Off.
		move.w	d6,d2
		add.w	-(a2),d2							    ; Map Y = Camera Y + Projection X Off.
		tst.w	d1									    ; Has the camera X gone off the left of the map?
		bmi.s	@outofbounds                            ; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d1                            ; Has the camera X gone off the right of the map?
		bge.s	@outofbounds                            ; If so, draw out of bounds.
		tst.w	d2                                      ; Has the camera Y gone off the top of the map?
		bmi.s	@outofbounds                            ; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d2                            ; Has the camera Y gone off the bottom of the map?
		bge.s	@outofbounds                            ; If so, draw out of bounds.
		asl.w	#9,d2								    ; Multiply by 512 to get row index.
		add.w	d2,d1								    ; Create final offset.
        move.l  d7,a1                                   ; Load fixed map ROM bank.
		add.l	d1,a1								    ; Go to corresponding byte in map data.
		move.b	(a1),d3								    ; Get the pixel.
		beq.s	@outofbounds						    ; If it's 0, just draw 0.
		move.b	d3,d4
		andi.b	#$F0,d4								    ; Is this a dither pixel?
		bne.s	@draw								    ; If so just send the raw map data as a pixel.
		asl.b	#4,d4								    ; Shift back flat colour into upper nybble.
		or.b	d4,d3								    ; Merge to form wide pixel.
@draw:
		move.b	d3,-(a0)							    ; Write 2 pixels to bitmap buffer.
		dbf		d0,@loop							    ; Loop until bitmap is fully drawn.
		rts

@outofbounds:
		move.b	#0,-(a0)							    ; Write 0 to bitmap.
		dbf		d0,@loop							    ; Loop until bitmap is fully drawn.
		rts

; 180-280 Degree draw loop.

Mode7_180DegDraw:
		subi.b	#1,d1								    ; Are in the 180-270 range?
		bpl.s	Mode7_270DegDraw					    ; If not, do next range.
@loop:
		move.w	d6,d2
		sub.w	-(a2),d2							    ; Map Y = Camera Y - Projection Y Off.
		move.w	d5,d1
		sub.w	-(a2),d1							    ; Map X = Camera X - Projection X Off.
		tst.w	d1									    ; Has the camera X gone off the left of the map?
		bmi.s	@outofbounds                        	; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d1                        	; Has the camera X gone off the right of the map?
		bge.s	@outofbounds                        	; If so, draw out of bounds.
		tst.w	d2                                  	; Has the camera Y gone off the top of the map?
		bmi.s	@outofbounds                        	; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d2                        	; Has the camera Y gone off the bottom of the map?
		bge.s	@outofbounds                        	; If so, draw out of bounds.
		asl.w	#9,d2									; Multiply by 512 to get row index.
		add.w	d2,d1									; Create final offset.
        move.l  d7,a1                               	; Load fixed map ROM bank.
		add.l	d1,a1									; Go to corresponding byte in map data.
		move.b	(a1),d3									; Get the pixel.
		beq.s	@outofbounds							; If it's 0, just draw 0.
		move.b	d3,d4
		andi.b	#$F0,d4									; Is this a dither pixel?
		bne.s	@draw									; If so just send the raw map data as a pixel.
		asl.b	#4,d4									; Shift back flat colour into upper nybble.
		or.b	d4,d3									; Merge to form wide pixel.
@draw:
		move.b	d3,-(a0)								; Write 2 pixels to bitmap buffer.
		dbf		d0,@loop								; Loop until bitmap is fully drawn.
		rts

@outofbounds:
		move.b	#0,-(a0)								; Write 0 to bitmap.
		dbf		d0,@loop								; Loop until bitmap is fully drawn.
		rts

; 270-0 Degree draw loop.

Mode7_270DegDraw:
@loop:
		move.w	d5,d1
		add.w	-(a2),d1								; Map X = Camera X + Projection Y Off.
		move.w	d6,d2
		sub.w	-(a2),d2								; Map Y = Camera Y - Projection X Off.
		tst.w	d1										; Has the camera X gone off the left of the map?
		bmi.s	@outofbounds                        	; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d1                        	; Has the camera X gone off the right of the map?
		bge.s	@outofbounds                        	; If so, draw out of bounds.
		tst.w	d2                                  	; Has the camera Y gone off the top of the map?
		bmi.s	@outofbounds                        	; If so, draw out of bounds.
		cmp.w	#MAP_SIZE,d2                        	; Has the camera Y gone off the bottom of the map?
		bge.s	@outofbounds                        	; If so, draw out of bounds.
		asl.w	#9,d2									; Multiply by 512 to get row index.
		add.w	d2,d1									; Create final offset.
        move.l  d7,a1                               	; Load fixed map ROM bank.
		add.l	d1,a1									; Go to corresponding byte in map data.
		move.b	(a1),d3									; Get the pixel.
		beq.s	@outofbounds							; If it's 0, just draw 0.
		move.b	d3,d4
		andi.b	#$F0,d4									; Is this a dither pixel?
		bne.s	@draw									; If so just send the raw map data as a pixel.
		asl.b	#4,d4									; Shift back flat colour into upper nybble.
		or.b	d4,d3									; Merge to form wide pixel.
@draw:
		move.b	d3,-(a0)								; Write 2 pixels to bitmap buffer.
		dbf		d0,@loop								; Loop until bitmap is fully drawn.
		rts

@outofbounds:
		move.b	#0,-(a0)								; Write 0 to bitmap.
		dbf		d0,@loop								; Loop until bitmap is fully drawn.
		rts

ProjectionTableTables:
        dc.l    ProjectionTable+($7000*1)-2             ; 0 Degrees.
        dc.l    ProjectionTable+($7000*2)-2             ; 6 Degrees.
        dc.l    ProjectionTable+($7000*3)-2             ; 12 Degrees.
        dc.l    ProjectionTable+($7000*4)-2             ; 18 Degrees.
        dc.l    ProjectionTable+($7000*5)-2             ; 24 Degrees.
        dc.l    ProjectionTable+($7000*6)-2             ; 30 Degrees.
        dc.l    ProjectionTable+($7000*7)-2             ; 36 Degrees.
        dc.l    ProjectionTable+($7000*8)-2             ; 42 Degrees.
        dc.l    ProjectionTable+($7000*9)-2             ; 48 Degrees.
        dc.l    ProjectionTable+($7000*$A)-2            ; 54 Degrees.
        dc.l    ProjectionTable+($7000*$B)-2            ; 60 Degrees.
        dc.l    ProjectionTable+($7000*$C)-2            ; 66 Degrees.
        dc.l    ProjectionTable+($7000*$D)-2            ; 72 Degrees.
        dc.l    ProjectionTable+($7000*$E)-2            ; 78 Degrees.
        dc.l    ProjectionTable+($7000*$F)-2            ; 84 Degrees.
        dc.l    ProjectionTable+($7000*$10)-2           ; 90 Degrees.
        ; You might think that since our code works in quadrants that this isn't needed, but since our angle is imprecise,
        ; there is space for a quadrant 0 90 degree rotation before going to quadrant 1 0 degrees.

; --------------------------------------------------
; Projection Table
; Format: 128x56 entries, X' Off.w, Y' Off.w
; Arranged in 4x8 tiles in a 32x7 tilemap.
; This gets around doing actual mode 7 calculations,
; but takes a lot of ROM, so I've dedicated it's own bank to it.
; --------------------------------------------------

    org $300000

ProjectionTable:
        incbin  "Projection Table.bin"
    
; --------------------------------------------------
; Map Data
; Format: 512x512, 8bpp image.
; Lower nybble determines base colour index.
; Upper nybble determines dither colour index.
; If no upper nybble is present, it stretches out the base colour.
; --------------------------------------------------

    org $380000

; Include map data here!