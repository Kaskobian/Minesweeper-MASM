; Procedure to push a tile (given by AX register) onto a custom stack 'processStack' for processing
pushProcessStack PROC uses eax edi
    and eax, 0000FFFFh                 ; Isolates lower 16 bits of EAX (ensuring tile offset is within bounds)
    mov BYTE PTR [tileState+eax*TYPE BYTE], opened   ; Marks the tile at offset EAX as 'opened' in 'tileState' array
    mov edi, processStackCount         ; Load current count of items in processStack into EDI
    mov [processStack+edi*TYPE WORD], ax   ; Add the tile offset (AX) to the processStack at position EDI
    inc processStackCount              ; Increment the stack count
    ret                                ; Return from the procedure
pushProcessStack ENDP

; Procedure to push a tile (given by AX register) onto a stack 'numOpenStack' for auto-opening numbered tiles
pushNumOpenStack PROC uses eax edi
    and eax, 0000FFFFh                 ; Isolates lower 16 bits of EAX
    mov edi, numStackCount             ; Load current count of items in numOpenStack into EDI
    mov [numOpenStack+edi*TYPE WORD], ax   ; Add the tile offset (AX) to the numOpenStack at position EDI
    inc numStackCount                  ; Increment the stack count
    ret                                ; Return from the procedure
pushNumOpenStack ENDP

; Procedure to open each tile in the processStack
openTiles PROC USES eax ebx edx esi
    L_loop:                            ; Start of loop to process each tile
        .IF processStackCount == 0     ; Check if the stack is empty
            ret                        ; Return if stack is empty
        .ENDIF

        ; Pop a tile offset from the processStack to AX
        dec processStackCount          ; Decrease stack count
        mov esi, processStackCount     ; Move new stack count to ESI
        mov ax, [processStack+esi*TYPE WORD]  ; Retrieve tile offset from stack into AX

        ; BX = tile offset
        movzx ebx, ax                  ; Move tile offset into EBX with zero-extension

        call trXY                      ; Call procedure trXY (possibly transforms offset to row/column)
        mov dx, ax                     ; Move transformed value to DX

        ; Record the start time if the game is not started yet
        .IF gameStarted == 0
            call GetMseconds           ; Call procedure to get milliseconds
            mov startTime, eax         ; Set startTime with the current time in milliseconds
            mov gameStarted, 1         ; Mark game as started
        .ENDIF

		; al: tile data (number or mine)
		xor eax, eax                   ; Clear EAX register to ensure no high-order bits are set
		mov al, [field+ebx*TYPE BYTE]  ; Load the tile data from the field array into the lower byte of EAX using EBX as the offset
		add al, '0'                    ; Convert the tile data (a number) to its ASCII character representation

		; The following commented out section would replace the '0' character with a space character
		; .IF al == '0'
		;   mov al, ' '
		; .ENDIF

		push dx                        ; Save the current value of DX on the stack
		inc dh                         ; Increment DH (high byte of DX), likely moving to the next row in a display or field
		inc dl                         ; Increment DL (low byte of DX), likely moving to the next column

		; gameover (player opens a mine)
		.IF al == '*'                  ; Check if the tile contains a mine ('*')
			mSetColor lightRed, lightGray ; Set the color for displaying the mine (light red text on light gray background)
			call Gotoxy                ; Move the cursor to the position specified by DX
			call WriteChar             ; Write the character in AL (the mine symbol) at the current cursor position
			mov gameover, 1            ; Set the gameover flag to indicate the game should end
			pop dx                     ; Restore the original value of DX from the stack
			ret                        ; Return from the procedure, as the game is over
		.ENDIF

		inc openCount                  ; Increment the count of opened tiles
		call printGameStatus           ; Update the game status display
		
		; Set the color based on the tile value (number on the tile)
		.IF al == '0'
			mSetColor lightGray, lightGray
		.ELSEIF al == '1'
			mSetColor lightBlue, lightGray		; cyan
		.ELSEIF al == '2'
			mSetColor lightgreen, lightGray
		.ELSEIF al == '3'
			mSetColor red, lightGray			; lightmagenta
		.ELSEIF al == '4'
			mSetColor blue, lightGray			; white
		.ELSEIF al == '5'
			mSetColor brown, lightGray			; cyan
		.ELSEIF al == '6'
			mSetColor magenta, lightGray		; lightcyan
		.ELSEIF al == '7'
			mSetColor black, lightGray			; white
		.ELSEIF al == '8'
			mSetColor gray, lightGray			; lightMagenta
		.ENDIF

		call Gotoxy                    ; Move the cursor to the position specified by DX again
		call WriteChar                 ; Write the character (now potentially colored) at the current cursor position

		; Restoring the original DX value from the stack
		pop dx

		; Check if the current tile is not empty, if so, continue the loop
		.IF BYTE PTR [field+ebx*TYPE BYTE] != 0
			jmp L_loop   ; Jump back to start of L_loop to process next tile
		.ENDIF

		; Auto-open logic for empty tiles (number == 0)
		mov ax, dx
		call getNeighborValidFlag  ; Call a procedure to determine valid neighboring tiles

		; Calculating the address of the northwest neighbor
		mov ax, bx
		sub ax, WORD PTR w         ; Subtract width to move one row up
		dec ax                     ; Decrement to move one column left

		; Check and open northwest neighbor
		test dl, 1010b             ; Check if northwest neighbor is valid (using bit mask)
		jnz _1                     ; Jump to label _1 if northwest neighbor is not valid
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0   ; Check if northwest neighbor is not already open
		jne _1                     ; Jump to label _1 if already open
			call pushProcessStack  ; Push northwest neighbor to process stack
		_1:
		inc ax                     ; Move to the north neighbor

	; The following blocks repeat the above logic for different neighboring tiles:
	; North, Northeast, West, Center (current tile), East, Southwest, South, and Southeast
	; Each block adjusts AX to point to the appropriate neighboring tile
	; Checks if the neighbor is valid and not already open
	; And if so, pushes the neighbor tile onto the process stack for processing

		pop dx			; Restoring the original DX value from the stack

		.IF BYTE PTR [field+ebx*TYPE BYTE] != 0
			jmp L_loop	; continue
		.ENDIF

		; ======== auto-open ========

		mov ax, dx
		call getNeighborValidFlag

		; ax = bx-w-1
		mov ax, bx
		sub ax, WORD PTR w
		dec ax

		test dl, 1010b
		jnz _1
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _1
			call pushProcessStack
		_1:
		inc ax

		test dl, 1000b
		jnz _2
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _2
			call pushProcessStack
		_2:
		inc ax

		test dl, 1001b
		jnz _3
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _3
			call pushProcessStack
		_3:
		add ax, WORD PTR w
		sub ax, 2

		test dl, 0010b
		jnz _4
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _4
			call pushProcessStack
		_4:
		inc ax

		_5:
		inc ax

		test dl, 0001b
		jnz _6
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _6
			call pushProcessStack
		_6:
		add ax, WORD PTR w
		sub ax, 2

		test dl, 0110b
		jnz _7
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _7
			call pushProcessStack
		_7:
		inc ax

		test dl, 0100b
		jnz _8
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _8
			call pushProcessStack
		_8:
		inc ax

		test dl, 0101b
		jnz _9
		cmp BYTE PTR [tileState+eax*TYPE BYTE], 0
		jne _9
			call pushProcessStack
		_9:

	jmp L_loop

	ret
openTiles ENDP

; Procedure for automatic opening of tiles in a Minesweeper game
numberAutoOpen PROC USES eax ebx edx esi
    mov bx, ax                ; Store AX in BX (likely the tile offset)
    call trXY                 ; Transform tile offset to row/column coordinates
    call getNeighborValidFlag ; Determine valid neighboring tiles

    mov ax, bx                ; Restore tile offset to AX
    sub ax, WORD PTR w        ; Move one row up (since w is the width of the field)
    dec ax                    ; Move one column left

    mov nFlagCounter, 0       ; Initialize flag counter to 0
    mov numStackCount, 0      ; Initialize stack count to 0

    ; The following blocks check each neighboring tile (in all 8 directions) around the current tile
    ; For each direction, it tests if the neighbor is valid and if it's flagged
    ; If valid and not flagged, it pushes the tile offset onto numOpenStack
    ; If flagged, increments the nFlagCounter
    ; This logic helps in determining if a numbered tile can auto-open its neighbors

   ; Check northwest neighbor
    test dl, 1010b            ; Test if northwest neighbor is valid
    jnz _1                    ; Jump to next check if not valid
        call pushNumOpenStack ; Push northwest neighbor onto numOpenStack if valid
    cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
    jne _1                    ; Jump if neighbor is not flagged
        inc nFlagCounter      ; Increment flag counter if neighbor is flagged
    _1:
    inc ax                    ; Move to the north neighbor

    ; Similar checks for north, northeast, west, east, southwest, south, southeast neighbors

	test dl, 1000b
	jnz _2
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _2
		inc nFlagCounter
	_2:
	inc ax

	test dl, 1001b
	jnz _3
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _3
		inc nFlagCounter
	_3:
	add ax, WORD PTR w
	sub ax, 2

	test dl, 0010b
	jnz _4
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _4
		inc nFlagCounter
	_4:
	inc ax

	_5:
	inc ax

	test dl, 0001b
	jnz _6
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _6
		inc nFlagCounter
	_6:
	add ax, WORD PTR w
	sub ax, 2

	test dl, 0110b
	jnz _7
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _7
		inc nFlagCounter
	_7:
	inc ax

	test dl, 0100b
	jnz _8
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _8
		inc nFlagCounter
	_8:
	inc ax

	test dl, 0101b
	jnz _9
		call pushNumOpenStack
	cmp BYTE PTR [tileState+eax*TYPE BYTE], flagged
	jne _9
		inc nFlagCounter
	_9:

    ; Check if the number of flags around the tile matches its value
    movzx eax, bx             ; Load current tile's offset into EAX
    mov dl, BYTE PTR [field+eax*TYPE BYTE]  ; Get the current tile's value
    .IF nFlagCounter != dl    ; If the number of flags does not match the tile's value
        ret                   ; Return from the procedure
    .ENDIF

    ; Logic to pop each tile offset from numOpenStack and process them
    L_open:
        .IF numStackCount == 0
            jmp stack_finish  ; If stack is empty, jump to stack_finish
        .ENDIF

        ; Pop a tile offset from numOpenStack
        dec numStackCount
        mov esi, numStackCount
        movzx eax, WORD PTR [numOpenStack+esi*TYPE WORD]

        ; If the tile is closed, push it onto processStack for opening
        .IF BYTE PTR [tileState+eax*TYPE BYTE] == closed
            call pushProcessStack
        .ENDIF
    jmp L_open                ; Continue popping and processing until stack is empty

    stack_finish:

    call openTiles            ; Call openTiles to process tiles in processStack

    ret                       ; Return from the procedure
numberAutoOpen ENDP

; Procedure to toggle a flag on a tile in a Minesweeper game
toggleFlag PROC USES eax ebx edx
    and eax, 0000FFFFh       ; Isolate the lower 16 bits of EAX (tile offset)
    mov ebx, eax             ; Move tile offset into EBX
    call trXY                ; Transform tile offset to row/column coordinates
    mov dx, ax               ; Store transformed coordinates in DX

    ; Check if tile is already opened; if so, return
    .IF BYTE PTR [tileState+ebx*TYPE BYTE] & opened
        ret                 ; Return if tile is already opened
    .ENDIF

    ; Toggle the flag status on the tile
    xor BYTE PTR [tileState+ebx*TYPE BYTE], flagged

    ; Update display based on the new flag status
    .IF BYTE PTR [tileState+ebx*TYPE BYTE] & flagged
        mov al, 'P'         ; Set character for flagged tile
        inc flagsCount      ; Increment flag count
        mSetColor lightRed, gray  ; Set color for flagged tile (light red on gray)
    .ELSEIF
        mov al, ' '         ; Set character for unflagged tile
        dec flagsCount      ; Decrement flag count
        mSetColor lightGray, gray ; Set color for unflagged tile (light gray on gray)
    .ENDIF

    inc dh                  ; Increment row
    inc dl                  ; Increment column
    call Gotoxy             ; Move cursor to the tile position
    call WriteChar          ; Display the flag character

    call printGameStatus    ; Update game status display

    ret                     ; Return from the procedure
toggleFlag ENDP
