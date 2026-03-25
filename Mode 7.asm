; ====================================================================================================
; Mode 7.asm (Version 4)
; Mario Kart/F-Zero styled floor renderer for the Mega Drive.
; 15/03/2026
; Rachel Harrison. (Kilo)
; Free to use, credit required.
; ====================================================================================================

; Constants

MODE7_MAP_SIZE			= 128	; Map size.
MODE7_ANGLES			= 64	; # of view angles.
MODE7_TILE_SIZE			= 4		; Internal tile size.

; Rendering phases
MODE7_RENDER_1ST		= 0		; Render init/first half of bitmap.
MODE7_RENDER_2ND		= 1		; Render second half of bitmap.
MODE7_RENDER_DMA		= 2		; Bitmap is ready for DMA.

; Internal resolution.
MODE7_INTERNAL_WIDTH	= 128
MODE7_INTERNAL_HEIGHT	= 32
MODE7_INTERNAL_SIZE		= MODE7_INTERNAL_WIDTH*MODE7_INTERNAL_HEIGHT

; Bitmap resolution
MODE7_BITMAP_WIDTH		= MODE7_INTERNAL_WIDTH	; Not multiplied by 2 because the Mega Drive uses 4BPP tiles.
MODE7_BITMAP_HEIGHT		= MODE7_INTERNAL_HEIGHT*2
MODE7_BITMAP_SIZE		= MODE7_BITMAP_WIDTH*MODE7_BITMAP_HEIGHT

; Projection map resolution
MODE7_PROJECTION_WIDTH	= MODE7_INTERNAL_WIDTH*2
MODE7_PROJECTION_HEIGHT = MODE7_INTERNAL_WIDTH*2
MODE7_PROJECTION_SIZE	= MODE7_PROJECTION_WIDTH*MODE7_PROJECTION_HEIGHT

; Tilemap tile dimensions.
MODE7_TILEMAP_WIDTH		= MODE7_INTERNAL_WIDTH/MODE7_TILE_SIZE
MODE7_TILEMAP_HEIGHT	= MODE7_INTERNAL_HEIGHT/MODE7_TILE_SIZE
MODE7_TILEMAP_SIZE		= MODE7_TILEMAP_WIDTH*MODE7_TILEMAP_HEIGHT

; Camera struct
MODE7_CAMERA_X		= 0
MODE7_CAMERA_Y		= 1
MODE7_CAMERA_ANGLE	= 2
MODE7_CAMERA_FILLER	= 3

	section	ram

; Variables
mode7_bitmap:			ds.b MODE7_BITMAP_SIZE				; Bitmap buffer.
mode7_map:				ds.b MODE7_MAP_SIZE*MODE7_MAP_SIZE	; Map data.
mode7_camera_game:		ds.l 1								; Game camera, constantly updated during game logic.
mode7_camera_render:	ds.l 1								; Render camera, only updated when a new frame is ready to draw.
mode7_render_step:		ds.b 1								; Rendering phase counter.

	section	rom

; Main floor draw function.
Mode7_DrawFloor:
		lea		(mode7_camera_game).w, a0	; Load camera variables.
		tst.b	(mode7_render_step).w		; Are we already drawing a frame?
		bne.w	Mode7_Draw2ndHalf			; If so, draw the 2nd half of the screen.
		move.l	(a0), d0
		cmp.l	d0, 4(a0)					; Does the game camera still match the previously rendered camera view?
		bne.s	Mode7_Draw1stHalf			; If not, start drawing.
		rts									; If a frame is not actively rendering and the camera has not changed, don't bother with an update.

; a0 = Camera variables/bitmap buffer.
; a1 = Projection map
; a2 = Map data.
; d0 = Camera X
; d1 = Camera Y
; d2 = Camera angle/Tile loop count.
; d3 = Row loop count.
; d4 = Offset X
; d5 = Offset Y/Map pixel pointer.
Mode7_Draw1stHalf:
		move.l	(a0), 4(a0)									; Update render camera for 2nd half and redraw checks.
		moveq	#0, d0
		moveq	#0, d1
		move.b	MODE7_CAMERA_X+4(a0), d0					; Load camera position.
		move.b	MODE7_CAMERA_Y+4(a0), d1
		move.b	MODE7_CAMERA_ANGLE+4(a0), d2				; Load camera angle.
		andi.w	#$FC, d2									; Keep within 64 angle range, mask out upper byte if anything was left there, also converts it into a long pointer.
		lea		(Mode7_ProjectionTablesTable).l, a1
		movea.l	(a1,d2.w), a1								; Load corresponding projection map.
		lea		(mode7_bitmap).w, a0						; Load bitmap table.
		movea.l	(mode7_map).w, a2							; Load map data.
		move.w	#(MODE7_TILEMAP_SIZE/2)-1. d2				; Set loop count for half of the bitmap.
.tileloop:
		moveq	#MODE7_TILE_SIZE-1, d3						; Loop for 4 rows.
.rowloop:
		; Pixel calculation. This is copied 4 times since unrolled loops are faster.
		rept 4
		moveq	#0,d4
		moveq	#0,d5
		move.b	(a1)+,d4									; Get X projection offset.
		add.b	d0,d4										; Add camera X.
		and.w	#$7F,d4										; Keep within map range.
		move.b	(a1)+,d5									; Get Y projection offset.
		add.b	d1,d5										; Add camera Y.
		and.w	#$7F,d5										; Keep within map range.
		asl.w	#7,d5										; Multiply by 128 to get row size offset.
		add.w	d4,d5										; Add together to get final pointer in the map data.
		move.b	(a2,d5.w),(a0)+								; Write map pixel to the buffer.
		endr
		move.l	#0, (a0)+									; Draw 8 blank pixels.
		dbf		d3, .rowloop								; Loop until all rows are drawn in the tile.
		dbf		d2, .tileloop								; Loop until half of the tiles are drawn.
		move.b	#MODE7_RENDER_2ND, (mode7_render_step).w	; Prepare for 2nd half.
		rts

Mode7_Draw2ndHalf:
		moveq	#0, d0
		moveq	#0, d1
		move.b	MODE7_CAMERA_X+4(a0), d0					; Load camera position.
		move.b	MODE7_CAMERA_Y+4(a0), d1
		move.b	MODE7_CAMERA_ANGLE+4(a0), d2				; Load camera angle.
		andi.w	#$FC, d2									; Keep within 64 angle range, also converts it into a long pointer.
		lea		(Mode7_ProjectionTablesTable2).l, a1
		movea.l	(a1,d2.w), a1								; Load corresponding projection map.
		lea		(mode7_bitmap+(MODE7_BITMAP_SIZE/2)).w, a0	; Load bitmap table at halfway point.
		movea.l	(mode7_map).w, a2							; Load map data.
		move.w	#(MODE7_TILEMAP_SIZE/2)-1. d2				; Set loop count for half of the bitmap.
.tileloop:
		moveq	#MODE7_TILE_SIZE-1, d3						; Loop for 4 rows.
.rowloop:
		; Pixel calculation. This is copied 4 times since unrolled loops are faster.
		rept 4
		moveq	#0,d4
		moveq	#0,d5
		move.b	(a1)+,d4									; Get X projection offset.
		add.b	d0,d4										; Add camera X.
		and.w	#$7F,d4										; Keep within map range.
		move.b	(a1)+,d5									; Get Y projection offset.
		add.b	d1,d5										; Add camera Y.
		and.w	#$7F,d5										; Keep within map range.
		asl.w	#7,d5										; Multiply by 128 to get row size offset.
		add.w	d4,d5										; Add together to get final pointer in the map data.
		move.b	(a2,d5.w),(a0)+								; Write map pixel to the buffer.
		endr
		move.l	#0, (a0)+									; Draw 8 blank pixels.
		dbf		d3, .rowloop								; Loop until all rows are drawn in the tile.
		dbf		d2, .tileloop								; Loop until half of the tiles are drawn.
		move.b	#MODE7_RENDER_DMA, (mode7_render_step).w	; The frame is ready for DMA.
		rts

Mode7_ProjectionTablesTable:
	set	i,0
	rept MODE7_ANGLES
		dc.l	Mode7_ProjectionTables+(i*MODE7_PROJECTION_SIZE)
	set i,i+1
	endr

Mode7_ProjectionTablesTable2:
	set	i,0
	rept MODE7_ANGLES
		dc.l	Mode7_ProjectionTables+(i*MODE7_PROJECTION_SIZE)+(MODE7_PROJECTION_SIZE/2)
	set i,i+1
	endr

Mode7_ProjectionTables:	binclude	"Projection Tables.bin"
	even