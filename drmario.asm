################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Ao Tian, 1010324472
# Student 2: Juntong Zhang, 1010157508
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
# Data Structure to represent the screen grid
DrMario_Grid:
    .space 4096 # 32 x 32 grid, each cell 4 bytes
# Used to store the position of pixels that have combined to four in a line. 
Delete_list:
    .space 512
# how many pixels' locations are in list
Delete_count:
    .word 0       
# Used to store those pixels that lost connection after deletion.
Fall_list:
    .space 512
# how many pixels are in the fall list
Fall_count:
    .word 0
# check delete for three times
Check_delete_count:
    .word 0
##############################################################################
# Mutable Data
##############################################################################

# Access Table for random color generation of capsule 0->Red, 1->Yellow, 2->Blue
RGB_Table:
    .word 0xff0000 # Red
    .word 0xffff00 # Yellow
    .word 0x0000ff # Blue

Virus_RGB_Table:
    .word 0xff0000 # Red Virus
    .word 0xffff00 # Yellow Virus
    .word 0x0000ff # Blue Virus

# Added with the address of the bitmap display will be the spawn location of the capsule
Capsule_Top_Offset: 
    .word 428
Capsule_Bottom_Offset:
    .word 556

# Save the old color in order to delete and redraw (movement), they will be given values inside label "generate_capsule"
Capsule_Top_Color:
    .word 0
Capsule_Bottom_Color:
    .word 0

#Save the next capsule in memory, put them on the right side outside of the bottle, and use them latter
Next_Capsule_Top_Color:
    .word 0
Next_Capsule_Bottom_Color:
    .word 0

#check if it's the first time we generate a capsule
First_time:
    .word 0

#used in easy feature 1, implement the gravity
Gravity_Time:
    .word 0
#used in easy feature 1, calculate how many capsule is generated. And increase game speed.
Repeat_time:
    .word 0
    
#used in easy feature 6, 0 = running, 1 = paused
Paused:
    .word 0
Paused_Backup:
    .space 4096   # Same size as the bitmap display (32×32 pixels × 4 bytes)

# Used when implement clockwise rotation movement (block being redraw are different based on the orientation)
Capsule_Orientation:
    .word 0 # Four state, rotation of 0 degree (0), 90 degrees (1), 180 degrees (2), and 270 degrees (3)

# Color to draw Dr_Mario
Dr_Mario_Dark_Grey:
    .word 0x4B4B4B

Dr_Mario_Light_Grey:
    .word 0xD3D3D3

Dr_Mario_Brown:
    .word 0x5D4037

Dr_Mario_White:
    .word 0xFFFFFF

Dr_Mario_Flesh:
    .word 0xF5CBA7

Dr_Mario_Light_Red:
    .word 0xE74C3C

Dr_Mario_Light_Blue:
    .word 0x3498DB

# Draw Virus
Red:
    .word 0xff0000 # Red

Yellow:
    .word 0xffff00 # Yellow

Blue:
    .word 0x0000ff # Blue

# Mario Theme Song
music_notes: # Consist of frequency, duration and pause time in between
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 69, 10, 110
    .word 65, 10, 110
    .word 62, 10, 110
    .word 62, 10, 110
    .word 60, 10, 110
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 64, 10, 110
    .word 64, 10, 400
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 69, 10, 110
    .word 65, 10, 110
    .word 62, 10, 110
    .word 62, 10, 110
    .word 58, 10, 110
    .word 56, 10, 110
    .word 58, 10, 110
    .word 62, 10, 110
    .word 65, 10, 110
    .word 62, 320, 250
    .word 60, 320, 250
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 64, 10, 110
    .word 64, 10, 400
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 64, 10, 110
    .word 64, 10, 400
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 69, 10, 110
    .word 68, 10, 110
    .word 64, 10, 110
    .word 64, 10, 110
    .word 60, 10, 110
    .word 64, 100, 200
    .word 66, 100, 200
    .word 64, 100, 600
    .word -1, 0, 0

music_counter: 
    .word 0        # Frame counter for music delay
    
note_index:    
    .word 0        # Which note we’re playing next
    
current_pause_remaining:  
    .word 0        # Pause between each note
    
##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize Gravity_time
    li $v0, 30
    syscall
    sw $a0, Gravity_Time
    
    # Initialize the game
    lw $t0, ADDR_DSPL # Resgiter $t0 stores the based address for display
    li $t1, 0xffffff # Resgiter $t1 stores the white color code
    # Initialize the Check_delete_count
    li $t2, 0
    la $t3, Check_delete_count
    sw $t2, 0($t3)

    # Initialize loop variables for drawing left side of the bottle
    add $t2, $zero, $zero # Set $t2 to zero, loop counter
    addi $t3, $zero, 26 # Set $t3 to 26, the height of our bottle (used in both draw_bottle_left&right)
    addi $t4 $zero, 648 # Set $t4 to 648, starting offset of left side of bottle

draw_bottle_left:
    beq $t2, $t3, bottle_right_setup # if $t2 == $t3 (0 -> 26), go to bottle_right_setup, finish drawing
    add $t5, $t0, $t4 # set $5 to be the byte pointer (start at 648) of the left side of bottle, and get updated (+128) for each loop iteration
    sw $t1, 0($t5) # draw the side with updated $t5
    addi $t4, $t4, 128 # $t4 = $t4 + 128 (update drawing coordinates)
    addi $t2, $t2, 1 # $t2 = $t2 + 1 (update loop counter)
    j draw_bottle_left

# Reset previous register to reuse them for drawing right side of the bottle
bottle_right_setup:
    add $t2, $zero, $zero # Set $t2 to zero again, loop counter
    addi $t4 $zero, 720 # Set $t4 to 648, starting offset of left side of bottle
    j draw_bottle_right

draw_bottle_right:
    beq $t2, $t3, bottle_bottom_setup # if $t2 == $t3 (0 -> 26), go to bottle_bottom_setup, finish drawing
    add $t5, $t0, $t4 # set $5 to be the byte pointer (start at 720) of the right side of bottle, and get updated (+128) for each loop iteration
    sw $t1, 0($t5) # draw the side with updated $t5
    addi $t4, $t4, 128 # $t4 = $t4 + 128 (update drawing coordinates)
    addi $t2, $t2, 1 # $t2 = $t2 + 1 (update loop counter)
    j draw_bottle_right

bottle_bottom_setup:
    add $t2, $zero, $zero # Set $t2 to zero again, loop counter
    addi $t3, $zero, 17 # Set $t3 to 17, the remaining length of our bottle (used in both draw_bottle_bottom&top)
    addi $t4 $zero, 3852 # Set $t4 to 3852, starting offset of the bottom of bottle
    j draw_bottle_bottom
    
draw_bottle_bottom:
    beq $t2, $t3, bottle_top_setup # if $t2 == $t3 (0 -> 17), go to bottle_top_setup, finish drawing
    add $t5, $t0, $t4 # set $5 to be the byte pointer (start at 3852) of the bottoom of bottle, and get updated (+4) for each loop iteration
    sw $t1, 0($t5) # draw the side with updated $t5
    addi $t4, $t4, 4 # $t4 = $t4 + 4 (update drawing coordinates)
    addi $t2, $t2, 1 # $t2 = $t2 + 1 (update loop counter)
    j draw_bottle_bottom

bottle_top_setup:
    add $t2, $zero, $zero # Set $t2 to zero again, loop counter
    addi $t4 $zero, 652 # Set $t4 to 652, starting offset of the top of bottle
    j draw_bottle_top
    
draw_bottle_top:
    beq $t2, $t3, bottle_neck # if $t2 == $t3 (0 -> 17), go to (), finish drawing
    
    beq $t2, 7, skip_top_gap # when it reach the top gap (7th), skip them (3 squares) and continue drawing
    
    add $t5, $t0, $t4 # set $5 to be the byte pointer (start at 652) of the top of bottle, and get updated (+4) for each loop iteration
    sw $t1, 0($t5) # draw the side with updated $t5
    addi $t4, $t4, 4 # $t4 = $t4 + 4 (update drawing coordinates)
    addi $t2, $t2, 1 # $t2 = $t2 + 1 (update loop counter)
    j draw_bottle_top

# bottle top has gaps in the middle, when the coordiants is reached, this label will be responsible for skip drwaing at that location
skip_top_gap:
    addi $t4, $t4, 12 # skip coordinates   
    addi $t2, $t2, 3 # update counter as usual
    j draw_bottle_top # go back to finish drawing the top

# Draw the neck of the bottle (additional four squares)
bottle_neck:
    sw $t1, 548($t0)
    la $t3, DrMario_Grid
    sw $t1, 548($t3)

    sw $t1, 564($t0)
    sw $t1, 564($t3)

    sw $t1, 420($t0)
    sw $t1, 420($t3)

    sw $t1, 436($t0)
    sw $t1, 436($t3)

    sw $t1, 676($t3)
    sw $t1, 692($t3)
    j Draw_Dr_Mario

# Hard feature 1: Play background music
play_next_note:
    la $t2, music_notes
    lw $t3, note_index
    mul $t4, $t3, 12 # index * 12 bytes (3 words)
    add $t5, $t2, $t4 # address of current note
    lw $t6, 0($t5) # frequency
    li $t8, -1
    beq $t6, $t8, reset_music_index

    lw $a0, 0($t5) # frequency
    lw $a1, 4($t5) # duration
    li $a2, 81 # instrument
    li $a3, 50 # volume
    li $v0, 31
    syscall

    lw $t7, 8($t5) # pause_frames (can be adjusted above in memory .data section)
    sw $t7, current_pause_remaining

    addi $t3, $t3, 1
    sw $t3, note_index
    jr $ra

reset_music_index:
    li $t3, 0
    sw $t3, note_index
    jr $ra

# Easy Feature 13: Draw Dr.Mario and Viruses
Draw_Dr_Mario:
    lw $t1, Dr_Mario_Dark_Grey
    lw $t2, Dr_Mario_Light_Grey
    lw $t3, Dr_Mario_Brown
    lw $t4, Dr_Mario_White
    lw $t5, Dr_Mario_Flesh
    lw $t6, Dr_Mario_Light_Red
    lw $t7, Dr_Mario_Light_Blue
    
    sw $t1, 3928($t0)
    sw $t2, 3932($t0)
    sw $t2, 3936($t0)
    sw $t2, 3940($t0)
    sw $t3, 3944($t0)
    sw $t2, 3948($t0)
    sw $t2, 3952($t0)
    sw $t2, 3956($t0)
    sw $t1, 3960($t0)

    sw $t1, 3804($t0)
    sw $t2, 3808($t0)
    sw $t2, 3812($t0)
    sw $t3, 3816($t0)
    sw $t2, 3820($t0)
    sw $t2, 3824($t0)
    sw $t1, 3828($t0)

    sw $t1, 3680($t0)
    sw $t1, 3684($t0)
    sw $t3, 3688($t0)
    sw $t1, 3692($t0)
    sw $t1, 3696($t0)
    sw $t1, 3700($t0)
    sw $t1, 3704($t0)

    sw $t1, 3548($t0)
    sw $t1, 3420($t0)
    sw $t1, 3292($t0)
    sw $t1, 3164($t0)

    sw $t1, 3572($t0)
    sw $t1, 3444($t0)
    sw $t1, 3316($t0)

    sw $t1, 3580($t0)
    sw $t1, 3452($t0)
    sw $t1, 3324($t0)
    sw $t1, 3196($t0)

    sw $t5, 3576($t0)
    sw $t5, 3448($t0)

    # Dr Mario‘s Tie
    sw $t1, 3432($t0)
    sw $t1, 3304($t0)
    sw $t1, 3172($t0)
    sw $t1, 3180($t0)

    sw $t4, 3552($t0)
    sw $t4, 3556($t0)
    sw $t4, 3560($t0)
    sw $t4, 3564($t0)
    sw $t4, 3568($t0)
    sw $t4, 3424($t0)
    sw $t4, 3428($t0)
    sw $t4, 3436($t0)
    sw $t4, 3440($t0)
    sw $t4, 3296($t0)
    sw $t4, 3300($t0)
    sw $t4, 3308($t0)
    sw $t4, 3312($t0)
    sw $t4, 3320($t0)
    sw $t4, 3168($t0)
    sw $t4, 3176($t0)
    sw $t4, 3184($t0)
    sw $t4, 3188($t0)
    sw $t4, 3192($t0)

    sw $t1, 3032($t0)
    sw $t4, 3036($t0)
    sw $t4, 3040($t0)
    sw $t1, 3044($t0)
    sw $t5, 3048($t0)
    sw $t5, 3052($t0)
    sw $t1, 3056($t0)
    sw $t4, 3060($t0)
    sw $t1, 3064($t0)

    sw $t1, 2904($t0)
    sw $t4, 2908($t0)
    sw $t1, 2912($t0)
    sw $t5, 2916($t0)
    sw $t5, 2920($t0)
    sw $t5, 2924($t0)
    sw $t5, 2928($t0)
    sw $t1, 2932($t0)

    sw $t4, 2776($t0)
    sw $t1, 2780($t0)
    sw $t5, 2784($t0)
    sw $t5, 2788($t0)
    sw $t5, 2792($t0)
    sw $t5, 2796($t0)
    sw $t5, 2800($t0)
    sw $t5, 2804($t0)
    sw $t1, 2808($t0)

    sw $t1, 2644($t0)
    sw $t4, 2648($t0)
    sw $t1, 2652($t0)
    sw $t5, 2656($t0)
    sw $t1, 2660($t0)
    sw $t5, 2664($t0)
    sw $t1, 2668($t0)
    sw $t5, 2672($t0)
    sw $t5, 2676($t0)
    sw $t1, 2680($t0)

    sw $t1, 2516($t0)
    sw $t5, 2520($t0)
    sw $t5, 2524($t0)
    sw $t1, 2528($t0)
    sw $t5, 2532($t0)
    sw $t1, 2536($t0)
    sw $t1, 2540($t0)
    sw $t3, 2544($t0)
    sw $t1, 2548($t0)

    sw $t1, 2388($t0)
    sw $t5, 2392($t0)
    sw $t1, 2396($t0)
    sw $t3, 2400($t0)
    sw $t1, 2404($t0)
    sw $t4, 2408($t0)
    sw $t4, 2412($t0)
    sw $t1, 2416($t0)
    sw $t3, 2420($t0)

    sw $t6, 2260($t0)
    sw $t6, 2264($t0)
    sw $t7, 2268($t0)
    sw $t7, 2272($t0)
    sw $t1, 2276($t0)
    sw $t4, 2280($t0)
    sw $t4, 2284($t0)
    sw $t1, 2288($t0)

    sw $t6, 2132($t0)
    sw $t6, 2136($t0)
    sw $t7, 2140($t0)
    sw $t7, 2144($t0)
    sw $t4, 2148($t0)
    sw $t1, 2152($t0)
    sw $t1, 2156($t0)

Draw_Virus:
    lw $t1, Red
    lw $t2, Yellow
    lw $t3, Blue

    sw $t1, 1756($t0)
    sw $t2, 1764($t0)
    sw $t3, 1772($t0)

generate_some_virus: # Now include slightly random mechanism
    # clean the field, and draw black color everywhere
    lw $t0, ADDR_DSPL # Resgiter $t0 stores the based address for display
    add $t1, $zero, $zero  # X
    add $t2, $zero, $zero  # Y
    la $t6, DrMario_Grid
    li $t9, 0x000000
    j outer_loop_for_clean
    outer_loop_for_clean:
        bge $t2, 24, end_loop_for_clean
        j inner_loop_for_clean
        inner_loop_for_clean:
            bge $t1, 17, inner_loop_for_clean_end
            mul $t3, $t2, 128
            mul $t4, $t1, 4
            addi $t5, $zero, 780
            add $t5, $t5, $t3
            add $t5, $t5, $t4
            add $t5, $t5, $t6
            sw $t9, 0($t5)
            addi $t1, $t1, 1
            j inner_loop_for_clean
        inner_loop_for_clean_end:
            add $t1, $zero, $zero
            addi $t2, $t2, 1
            j outer_loop_for_clean
        
    end_loop_for_clean:
        add $t1, $zero, $zero
        add $t2, $zero, $zero
        
    # First Virus
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    la $t2, Virus_RGB_Table # Let $t2 hold the address of Virus_RGB_Table for index accessing
    sll $t3, $t1, 2 # Shift logical left by 2 (equivalent to *4) stored in $t3
    add $t4, $t3, $t2 # $t4 = $t3 + $t2 (generated indices * 4) + address of Virus_RGB_Table = address of the color we want
    lw $t5, 0($t4) # $t5 hold the randomly generated virus color

    # Random location of virus (+ 13x128) so it start at lower half of the playfield  (+ 3x4) for horizontal offset as well
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 17 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 16}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    mul $t1, $t1, 128 # Store random vertical offset
    addi $t1, $t1, 1664 # (+ 13x128) so it start at lower half of the playfield

    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 16 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 15}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    mul $t2, $t2, 4 # Store random horizontal offset
    addi $t2, $t2, 12 # (+ 3x4) so it start in the playfield instead of potentially outbound

    add $t2, $t2, $t1 # $t2 now store the final offset we want *
    move $t3, $t2 # Store $t2's content also to $t3 for a second use

    # Store landed capsule's color in DrMario Grid
    la $t1, DrMario_Grid # Stored the address of DrMario Grid into $t5

    # Start putting stuff into Dr Mario Grid (store color in the mario grid for collision checking when movement is triggered)
    add $t3, $t1, $t3 # Grid + Virus offset
    sw $t5, 0($t3) # Store virus color in grid in the corresponding location
    
    add $t2, $t2, $t0 # Final random Offset we want on the bitmap
    sw $t5, 0($t2)
    
    # Second Virus
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    la $t2, Virus_RGB_Table # Let $t2 hold the address of Virus_RGB_Table for index accessing
    sll $t3, $t1, 2 # Shift logical left by 2 (equivalent to *4) stored in $t3
    add $t4, $t3, $t2 # $t4 = $t3 + $t2 (generated indices * 4) + address of Virus_RGB_Table = address of the color we want
    lw $t5, 0($t4) # $t5 hold the randomly generated virus color
    
    # Random location of virus (+ 13x128) so it start at lower half of the playfield  (+ 3x4) for horizontal offset as well
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 17 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 16}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    mul $t1, $t1, 128 # Store random vertical offset
    addi $t1, $t1, 1664 # (+ 13x128) so it start at lower half of the playfield

    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 16 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 15}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    mul $t2, $t2, 4 # Store random horizontal offset
    addi $t2, $t2, 12 # (+ 3x4) so it start in the playfield instead of potentially outbound

    add $t2, $t2, $t1 # $t2 now store the final offset we want *
    move $t3, $t2 # Store $t2's content also to $t3 for a second use

    # Store landed capsule's color in DrMario Grid
    la $t1, DrMario_Grid # Stored the address of DrMario Grid into $t5

    # Start putting stuff into Dr Mario Grid (store color in the mario grid for collision checking when movement is triggered)
    add $t3, $t1, $t3 # Grid + Virus offset
    sw $t5, 0($t3) # Store virus color in grid in the corresponding location
    
    add $t2, $t2, $t0 # Final random Offset we want on the bitmap
    sw $t5, 0($t2)

    # Third Virus
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    la $t2, Virus_RGB_Table # Let $t2 hold the address of Virus_RGB_Table for index accessing
    sll $t3, $t1, 2 # Shift logical left by 2 (equivalent to *4) stored in $t3
    add $t4, $t3, $t2 # $t4 = $t3 + $t2 (generated indices * 4) + address of Virus_RGB_Table = address of the color we want
    lw $t5, 0($t4) # $t5 hold the randomly generated virus color
    
    # Random location of virus (+ 13x128) so it start at lower half of the playfield  (+ 3x4) for horizontal offset as well
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 17 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 16}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    mul $t1, $t1, 128 # Store random vertical offset
    addi $t1, $t1, 1664 # (+ 13x128) so it start at lower half of the playfield

    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 16 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 15}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    mul $t2, $t2, 4 # Store random horizontal offset
    addi $t2, $t2, 12 # (+ 3x4) so it start in the playfield instead of potentially outbound

    add $t2, $t2, $t1 # $t2 now store the final offset we want *
    move $t3, $t2 # Store $t2's content also to $t3 for a second use

    # Store landed capsule's color in DrMario Grid
    la $t1, DrMario_Grid # Stored the address of DrMario Grid into $t5

    # Start putting stuff into Dr Mario Grid (store color in the mario grid for collision checking when movement is triggered)
    add $t3, $t1, $t3 # Grid + Virus offset
    sw $t5, 0($t3) # Store virus color in grid in the corresponding location
    
    add $t2, $t2, $t0 # Final random Offset we want on the bitmap
    sw $t5, 0($t2)

    # Fourth Virus
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    la $t2, Virus_RGB_Table # Let $t2 hold the address of Virus_RGB_Table for index accessing
    sll $t3, $t1, 2 # Shift logical left by 2 (equivalent to *4) stored in $t3
    add $t4, $t3, $t2 # $t4 = $t3 + $t2 (generated indices * 4) + address of Virus_RGB_Table = address of the color we want
    lw $t5, 0($t4) # $t5 hold the randomly generated virus color
    
    # Random location of virus (+ 13x128) so it start at lower half of the playfield  (+ 3x4) for horizontal offset as well
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 17 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 16}
    syscall
    move $t1, $a0 # Overwrite the content of $t1 with the randomly generated indices
    mul $t1, $t1, 128 # Store random vertical offset
    addi $t1, $t1, 1664 # (+ 13x128) so it start at lower half of the playfield

    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 16 # Set upper bound to be 17, so random number is one of {0, 1, 2, ... , 15}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    mul $t2, $t2, 4 # Store random horizontal offset
    addi $t2, $t2, 12 # (+ 3x4) so it start in the playfield instead of potentially outbound

    add $t2, $t2, $t1 # $t2 now store the final offset we want *
    move $t3, $t2 # Store $t2's content also to $t3 for a second use

    # Store landed capsule's color in DrMario Grid
    la $t1, DrMario_Grid # Stored the address of DrMario Grid into $t5

    # Start putting stuff into Dr Mario Grid (store color in the mario grid for collision checking when movement is triggered)
    add $t3, $t1, $t3 # Grid + Virus offset
    sw $t5, 0($t3) # Store virus color in grid in the corresponding location
    
    add $t2, $t2, $t0 # Final random Offset we want on the bitmap
    sw $t5, 0($t2)

### Bottle finished, Starting Draw Capsules
generate_capsule:
    lw $t3, First_time # first time is a global variable, whether it's the first time we generate a capsule
    addi $t4, $zero, 0 # load a black pixel
    bge $t3, $t4, generate_next_capsule_for_the_first_time
    j regular_generate_next_capsule

#if this is the first capsule generated, we need to generate the next capsule
generate_next_capsule_for_the_first_time:
    # top half
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    
    # bottom half
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    move $t3, $a0 # Overwrite the content of $t3 with the randomly generated indices

    la $t4, RGB_Table # Let $t4 hold the address of RGB_Table for index accessing
    sll $t5, $t2, 2 # Shift logical left by 2 (equivalent to *4) stored in $t5
    add $t6, $t4, $t5 # $t6 = $t4 + $t5 (generated indices * 4) + address of RGB_Table = address of the color we want
    lw $t7, 0($t6) # $t7 hold the color of the top half of the capsule

    sll $t5, $t3, 2 # do the same thing for bottom half of the capsule
    add $t6, $t4, $t5
    lw $t8, 0($t6) # t8 hold the color of the bottom half of the capsule
    
    # Draw them in the bottle's bottle_neck
    sw $t7, 428($t0)
    sw $t8, 556($t0)

    # Save the color in memory
    sw $t7, Capsule_Top_Color # Store the color in $t7 into memory address labelled Capsule_Top_Color
    sw $t8, Capsule_Bottom_Color # Store the color in $t8 into memory address labelled Capsule_Bottom_Color

    #generate the next capsule
    #Top half of the next capsule
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    move $t2, $a0 # Overwrite the content of $t3 with the randomly generated indices

    #Bottom half of the next capsule
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    move $t3, $a0 # Overwrite the content of $t3 with the randomly generated indices

    #redundant steps
    la $t4, RGB_Table # Let $t4 hold the address of RGB_Table for index accessing
    sll $t5, $t2, 2 # Shift logical left by 2 (equivalent to *4) stored in $t5
    add $t6, $t4, $t5 # $t6 = $t4 + $t5 (generated indices * 4) + address of RGB_Table = address of the color we want
    lw $t7, 0($t6) # $t7 hold the color of the top half of the capsule

    sll $t5, $t3, 2 # do the same thing for bottom half of the capsule
    add $t6, $t4, $t5
    lw $t8, 0($t6) # t8 hold the color of the bottom half of the capsule
    
    # Draw the next capsule in the right side of the bottle
    sw $t7, 988($t0)
    sw $t8, 1116($t0)

    #store them in memory
    sw $t7, Next_Capsule_Top_Color
    sw $t8, Next_Capsule_Bottom_Color

    addi $t7, $zero, -1
    sw $t7, First_time

     # Initialize repeat_time
    add $t1, $zero, $zero       
    sw $t1, Repeat_time
    
    j game_loop
    
    #if not the first time, the function will generate the next capsule and put it on the right side
regular_generate_next_capsule:
    # draw the next capsule that we generated last time on the bottle's bottle_neck
    lw $t7, 988($t0)
    lw $t8, 1116($t0)
    sw $t7, 428($t0)   #load Next_Capsule_Top_Color to t7
    sw $t8, 556($t0)   #load Next_Capsule_Bootom_Color to t8
    sw $t7, Capsule_Top_Color
    sw $t8, Capsule_Bottom_Color
    
    # top half
    li $v0, 42 # $v0 stores system call 42 for random number generation with upper bounds
    li $a0, 0 # Use default random number generator, result random number result will be stored back to $a0
    li $a1, 3 # Set upper bound to be 3, so random number is one of {0, 1, 2}
    syscall
    move $t2, $a0 # Overwrite the content of $t2 with the randomly generated indices
    
    # bottom half
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    move $t3, $a0 # Overwrite the content of $t3 with the randomly generated indices

    la $t4, RGB_Table # Let $t4 hold the address of RGB_Table for index accessing
    sll $t5, $t2, 2 # Shift logical left by 2 (equivalent to *4) stored in $t5
    add $t6, $t4, $t5 # $t6 = $t4 + $t5 (generated indices * 4) + address of RGB_Table = address of the color we want
    lw $t7, 0($t6) # $t7 hold the color of the top half of the capsule

    sll $t5, $t3, 2 # do the same thing for bottom half of the capsule
    add $t6, $t4, $t5
    lw $t8, 0($t6) # t8 hold the color of the bottom half of the capsule

    # Draw the next capsule in the right side of the bottle
    sw $t7, 988($t0)
    sw $t8, 1116($t0)

    sw $t7, Next_Capsule_Top_Color
    sw $t8, Next_Capsule_Bottom_Color

    # increase repeat_time each time capsule is generated. for easy feature 2
    lw $t1, Repeat_time
    addi $t1, $t1, 1        
    sw $t1, Repeat_time
    
    j game_loop

Quit_q:
	li $v0, 10 # Quit gracefully
	syscall

Move_Down_s:
    # Based address for bitmap is in $t0
    # Load current position
    lw $t1, Capsule_Top_Offset # $t1 is the offset of the top half of the capsule
    lw $t2, Capsule_Bottom_Offset # $t2 is the offset of the bottom half of the capsule

    # Before do anything, check collision with wall 
    bge $t1, 3712, skip_movement_bottom
    bge $t2, 3712, skip_movement_bottom

    # Now check with blocks and virus on the bitmap
    la $t3, DrMario_Grid
    addi $t4, $t1, 128 # Location below Capsule top
    addi $t5, $t2, 128 # Location below Capsile bottom

    add $t6, $t3, $t4 # Location below Capule top in the Mario Grid ($t6 is now a location inside our Mario Grid for checking purposes)
    lw $t7, 0($t6) # Load content of location below Capsule top into $t7 for further check (this is a location is mario grid, if not 0, a grid is occupied by color)
    bne $t7, $zero, skip_movement_bottom

    add $t6, $t3, $t5 # Location below Capule bottom in the Mario Grid
    lw $t7, 0($t6) # Load content of location below Capsule bottom into $t7 for further check
    bne $t7, $zero, skip_movement_bottom
    
    li $t3, 0x000000 # Color Black, act as eraser
    add $t4, $t0, $t1 # $t4 = $t0 + $t1, the current position of the top half of the Capsule_Top_Color
    add $t5, $t0, $t2 # $t5 = $t0 + $t2, the current position of the bottom half of the Capsule_Top_Color
    sw $t3, 0($t4) # erase both halves of the capsule by painting black
    sw $t3, 0($t5)

    addi $t1, $t1, 128
    addi $t2, $t2, 128

    sw $t1, Capsule_Top_Offset # Store the updated position in $t1 into Capsule_Top_Offset
    sw $t2, Capsule_Bottom_Offset # Store the updated position in $t2 into Capsule_Bottom_Offset

    lw $t6, Capsule_Top_Color # Load the color of the capsule, capsule top color
    lw $t7, Capsule_Bottom_Color # capsule bottom color

    add $t4, $t0, $t1 # Since t1 & t2 get updated (+128), we store the shifted location back to $t4 and $t5
    add $t5, $t0, $t2

    sw $t6, 0($t4)
    sw $t7, 0($t5)

    # Falling sound
    li $v0, 31
    li $a0, 45
    li $a1, 10
    li $a2, 36
    li $a3, 50
    syscall
    
    j game_loop

Move_Left_a:
    # Based address for bitmap is in $t0
    # Load current position
    lw $t1, Capsule_Top_Offset # $t1 is the offset of the top half of the capsule
    lw $t2, Capsule_Bottom_Offset # $t2 is the offset of the bottom half of the capsule

    # Before do anything, check collision with wall 
    addi $t3, $zero, 128 # divide offset by 128, if remainder is 12, is it at the left wall, stop movement
    div $t1, $t3
    mfhi $t4
    ble $t4, 12, skip_movement
    div $t2, $t3
    mfhi $t4
    ble $t4, 12, skip_movement

    # Now check with blocks and virus on the bitmap
    la $t3, DrMario_Grid
    addi $t4, $t1, -4 # Location left of Capsule top
    addi $t5, $t2, -4 # Location left of Capsile bottom

    add $t6, $t3, $t4 # Location left of Capule top in the Mario Grid ($t6 is now a location inside our Mario Grid for checking purposes)
    lw $t7, 0($t6) # Load content of location left of Capsule top into $t7 for further check (this is a location is mario grid, if not 0, a grid is occupied by color)
    bne $t7, $zero, skip_movement

    add $t6, $t3, $t5 # Location left of Capule bottom in the Mario Grid
    lw $t7, 0($t6) # Load content of location left of Capsule bottom into $t7 for further check
    bne $t7, $zero, skip_movement
    
    # Start moving
    li $t3, 0x000000 # Color Black, act as eraser
    add $t4, $t0, $t1 # $t4 = $t0 + $t1, the current position of the top half of the Capsule_Top_Color
    add $t5, $t0, $t2 # $t5 = $t0 + $t2, the current position of the bottom half of the Capsule_Top_Color
    sw $t3, 0($t4) # erase both halves of the capsule by painting black
    sw $t3, 0($t5)

    addi $t1, $t1, -4
    addi $t2, $t2, -4

    sw $t1, Capsule_Top_Offset # Store the updated position in $t1 into Capsule_Top_Offset
    sw $t2, Capsule_Bottom_Offset # Store the updated position in $t2 into Capsule_Bottom_Offset

    lw $t6, Capsule_Top_Color # Load the color of the capsule, capsule top color
    lw $t7, Capsule_Bottom_Color # capsule bottom color

    add $t4, $t0, $t1 # Since t1 & t2 get updated (+128), we store the shifted location back to $t4 and $t5
    add $t5, $t0, $t2

    sw $t6, 0($t4)
    sw $t7, 0($t5)
    
    j game_loop

Move_Right_d:
    # Based address for bitmap is in $t0
    # Load current position
    lw $t1, Capsule_Top_Offset # $t1 is the offset of the top half of the capsule
    lw $t2, Capsule_Bottom_Offset # $t2 is the offset of the bottom half of the capsule

    # Before do anything, check collision with wall 
    addi $t3, $zero, 128 # divide offset by 128, if remainder is 76, is it at the right wall, stop movement
    div $t1, $t3
    mfhi $t4
    bge $t4, 76, skip_movement
    div $t2, $t3
    mfhi $t4
    bge $t4, 76, skip_movement

    # Now check with blocks and virus on the bitmap
    la $t3, DrMario_Grid
    addi $t4, $t1, 4 # Location right of Capsule top
    addi $t5, $t2, 4 # Location right of Capsile bottom

    add $t6, $t3, $t4 # Location right of Capule top in the Mario Grid ($t6 is now a location inside our Mario Grid for checking purposes)
    lw $t7, 0($t6) # Load content of location right of Capsule top into $t7 for further check (this is a location is mario grid, if not 0, a grid is occupied by color)
    bne $t7, $zero, skip_movement

    add $t6, $t3, $t5 # Location right of Capule bottom in the Mario Grid
    lw $t7, 0($t6) # Load content of location right of Capsule bottom into $t7 for further check
    bne $t7, $zero, skip_movement

    # Start drawing
    li $t3, 0x000000 # Color Black, act as eraser
    add $t4, $t0, $t1 # $t4 = $t0 + $t1, the current position of the top half of the Capsule_Top_Color
    add $t5, $t0, $t2 # $t5 = $t0 + $t2, the current position of the bottom half of the Capsule_Top_Color
    sw $t3, 0($t4) # erase both halves of the capsule by painting blacks
    sw $t3, 0($t5)

    addi $t1, $t1, 4
    addi $t2, $t2, 4

    sw $t1, Capsule_Top_Offset # Store the updated position in $t1 into Capsule_Top_Offset
    sw $t2, Capsule_Bottom_Offset # Store the updated position in $t2 into Capsule_Bottom_Offset

    lw $t6, Capsule_Top_Color # Load the color of the capsule, capsule top color
    lw $t7, Capsule_Bottom_Color # capsule bottom color

    add $t4, $t0, $t1 # Since t1 & t2 get updated (+128), we store the shifted location back to $t4 and $t5
    add $t5, $t0, $t2

    sw $t6, 0($t4)
    sw $t7, 0($t5)
    
    j game_loop

Rotate_Clockwise_w:
    # Based address for bitmap is in $t0
    # Load current position
    lw $t1, Capsule_Top_Offset # $t1 is the offset of the top half of the capsule
    lw $t2, Capsule_Bottom_Offset # $t2 is the offset of the bottom half of the capsule
    lw $t3, Capsule_Orientation # Save the status in $3, (4 states: 0, 90, 180, 270 degrees)
    
    # Before do anything, check collision with wall (right wall only, due to nature of rotate only extend in right direction)
    # When it is 90 or 270 degree, you can still rotate if >=76, otherwise you cannot!
    addi $t4, $zero, 128 # divide offset by 128, if remainder is 76, is it at the right wall, stop movement
    div $t1, $t4
    mfhi $t5
    bge $t5, 76, check_rotation_1 # Check if both halves of the capsule are against the wall

Rotate_Clockwise_w_continued:
    # Now check with blocks and virus on the bitmap
    la $t4, DrMario_Grid
    addi $t5, $t1, 4 # Location right of Capsule top
    addi $t6, $t2, 4 # Location right of Capsile bottom
    
    # block is vertical, so check the right of it (orientation status 0 or 2)
    beq $t3, 0, check_first_half_right
    beq $t3, 2, check_first_half_right

    # block is horizontal, so check the top of it (orientation status 1 or 3)
    addi $t5, $t1, -128 # Location top of Capsule top
    addi $t6, $t2, -128 # Location top of Capsile bottom
    j check_first_half_top

check_first_half_right:
    add $t7, $t4, $t5 # Location right of Capule top in the Mario Grid ($t6 is now a location inside our Mario Grid for checking purposes)
    lw $t8, 0($t7) # Load content of location right of Capsule top into $t7 for further check (this is a location is mario grid, if not 0, a grid is occupied by color)
    beq $t8, $zero, check_second_half_right
    j skip_movement

check_second_half_right: # Not allowed to rotate if both halves of the capsule are against the obstacle
    add $t7, $t4, $t6 # Location right of Capule bottom in the Mario Grid
    lw $t8, 0($t7) # Load content of location right of Capsule bottom into $t7 for further check
    beq $t8, $zero, erase_and_rotate
    j skip_movement

check_first_half_top:
    add $t7, $t4, $t5 # Location top of Capule top in the Mario Grid ($t6 is now a location inside our Mario Grid for checking purposes)
    lw $t8, 0($t7) # Load content of location top of Capsule top into $t7 for further check (this is a location is mario grid, if not 0, a grid is occupied by color)
    beq $t8, $zero, check_second_half_top
    j skip_movement

check_second_half_top:
    add $t7, $t4, $t6 # Location top of Capule bottom in the Mario Grid
    lw $t8, 0($t7) # Load content of location top of Capsule bottom into $t7 for further check
    beq $t8, $zero, erase_and_rotate
    j skip_movement

erase_and_rotate:
    # Reload info to resolve potential replacement of information in previous steps
    lw $t1, Capsule_Top_Offset # $t1 is the offset of the top half of the capsule
    lw $t2, Capsule_Bottom_Offset # $t2 is the offset of the bottom half of the capsule
    lw $t3, Capsule_Orientation # Save the status in $3, (4 states: 0, 90, 180, 270 degrees)
    
    li $t4, 0x000000 # Color Black, act as eraser
    add $t5, $t0, $t1 # $t4 = $t0 + $t1, the current position of the top half of the Capsule_Top_Color
    add $t6, $t0, $t2 # $t5 = $t0 + $t2, the current position of the bottom half of the Capsule_Top_Color
    sw $t4, 0($t5) # erase both halves of the capsule by painting blacks
    sw $t4, 0($t6)

    lw $t7, Capsule_Top_Color # Load the color of the capsule, capsule top color
    lw $t8, Capsule_Bottom_Color # capsule bottom color

    j continue_rotation

check_rotation_1:
    # divide offset by 128, if remainder is 76, is it at the right wall, stop movement
    div $t2, $t4
    mfhi $t5
    bge $t5, 76, skip_movement
    j Rotate_Clockwise_w_continued

continue_rotation: # handle four cases
    beq $t3, 0, degree_0
    beq $t3, 1, degree_90
    beq $t3, 2, degree_180
    beq $t3, 3, degree_270

degree_0: # the top half move to the right of bottom half
    addi $t1, $t2, 4
    addi $t3, $t3, 1 # update states
    j finish_rotating

degree_90: # the top half now is at the position of bottom half, and bottom half is above top half
    move $t1, $t2
    addi $t2, $t2, -128
    addi $t3, $t3, 1 # update states
    j finish_rotating

degree_180: # the bottom half move to the right of top half
    addi $t2, $t1, 4
    addi $t3, $t3, 1 # update states
    j finish_rotating

degree_270: # the bottom half now is at the position of top half, and top half is above bottom half (initial state)
    move $t2, $t1
    addi $t1, $t1, -128
    li $t3, 0
    j finish_rotating

# This part is responsible for drawing the new capsule at the correct location after rotating
finish_rotating:
    # Save all the updated information of the capsule
    sw $t1, Capsule_Top_Offset # Store the updated position in $t1 into Capsule_Top_Offset
    sw $t2, Capsule_Bottom_Offset # Store the updated position in $t2 into Capsule_Bottom_Offset
    sw $t3, Capsule_Orientation # Store the updated orientation in $t3 into Capsule_Orientation

    # Start Redrawing at the updated location $t5 & $t6 with saved color $t7 & $t8
    add $t5, $t0, $t1
    add $t6, $t0, $t2
    sw $t7, 0($t5)
    sw $t8, 0($t6)

    # Play rotation sound
    li $v0, 31
    li $a0, 40
    li $a1, 10
    li $a2, 26
    li $a3, 50
    syscall
    
    j game_loop

skip_movement:
    j game_loop

skip_movement_bottom:
    # Store landed capsule's color in DrMario Grid
    la $t5, DrMario_Grid # Stored the address of DrMario Grid into $t5

    # Load the data needed to store in Dr Mario's Grid into 4 register
    lw $t1, Capsule_Top_Offset
    lw $t2, Capsule_Bottom_Offset
    lw $t3, Capsule_Top_Color # Top and Bottom are color are relative to the initially position, they can be rotated to different relative position
    lw $t4, Capsule_Bottom_Color

    # Start putting stuff into Dr Mario Grid (store color in the mario grid for collision checking when movement is triggered)
    add $t6, $t5, $t1 # Grid + Capsule top offset
    sw $t3, 0($t6) # Store top color in grid
    add $t6, $t5, $t2 # Grid + Capsule bottom offset
    sw $t4, 0($t6) # Store bottom color in grid
    j check_vertical_match

check_vertical_match: # row go from 7 (6 x 128) to 30 (29 x 128), and the column + 1, row go from 7 to 30 again
    la $t1, DrMario_Grid
    addi $t2, $zero, 6 # The starting row
    addi $t3, $zero, 3 # The starting column
    blt $t2, 30, incre_row

incre_row:
    addi $t2, $t2, 1
    beq $t2, 30, incre_column

incre_column:
    addi $t3, $t3, 1
    li $t2, 6 # Reset row to iterate over a new row
    
    j check_horizontal_match

check_horizontal_match:
    j reset_capsule_to_neck_and_generate

reset_capsule_to_neck_and_generate:
    # Landing sound
    li $v0, 31
    li $a0, 90
    li $a1, 10
    li $a2, 46
    li $a3, 30
    syscall
    
    # Now we are at bottom, generate new capsule at bottle neck
    addi $t7, $zero, 428
    addi $t8, $zero, 556
    addi $t9, $zero, 0
    sw $t7, Capsule_Top_Offset
    sw $t8, Capsule_Bottom_Offset
    sw $t9, Capsule_Orientation
    j check_game_over

# Easy feature 4: game over
check_game_over:
    li $t1, 0x000000   # Black (empty)
    lw $t2, 428($t0)   # Check bottle neck top
    lw $t3, 556($t0)   # Check bottle neck bottom
    lw $t4, 432($t0) 
    lw $t5, 424($t0) 
    lw $t6, 552($t0)
    lw $t7, 560($t0)

    bne $t2, $t1, Game_Over
    bne $t3, $t1, Game_Over
    bne $t4, $t1, Game_Over
    bne $t5, $t1, Game_Over
    bne $t6, $t1, Game_Over
    bne $t7, $t1, Game_Over
    j check_delete

Game_Over:
    # Clear screen first 
    # $t1 = black (0x000000)
    # $t2 = loop counter (1024 pixels)
    li $t1, 0x000000        # Black color
    li $t2, 0               # Start at pixel 0
    li $t3, 1024            # Total number of pixels
    
    clear_screen_loop:
        sll $t4, $t2, 2     # Multiply counter by 4 to get byte offset
        add $t5, $t0, $t4   # $t5 = address of pixel
        sw $t1, 0($t5)      # Set pixel to black
        addi $t2, $t2, 1    # Next pixel
        blt $t2, $t3, clear_screen_loop

    # Draw "GAME OVER" in blocks using sw $t1, offset($t0)
    li $t1, 0xabcdef # $t1 = special color
    # Letter 'G'
    sw $t1, 792($t0)
    sw $t1, 796($t0)
    sw $t1, 800($t0)
    sw $t1, 804($t0)
    sw $t1, 920($t0)
    sw $t1, 1048($t0)
    sw $t1, 1176($t0)
    sw $t1, 1304($t0)
    sw $t1, 1432($t0)
    sw $t1, 1436($t0)
    sw $t1, 1440($t0)
    sw $t1, 1444($t0)
    sw $t1, 1316($t0)
    sw $t1, 1188($t0)
    sw $t1, 1184($t0)
    # Letter 'A'
    sw $t1, 820($t0)
    sw $t1, 944($t0)
    sw $t1, 1068($t0)
    sw $t1, 1196($t0)
    sw $t1, 1324($t0)
    sw $t1, 1452($t0)
    sw $t1, 952($t0)
    sw $t1, 1084($t0)
    sw $t1, 1212($t0)
    sw $t1, 1340($t0)
    sw $t1, 1468($t0)
    sw $t1, 1200($t0)
    sw $t1, 1204($t0)
    sw $t1, 1208($t0)
    # Letter 'M'
    sw $t1, 836($t0)
    sw $t1, 964($t0)
    sw $t1, 1092($t0)
    sw $t1, 1220($t0)
    sw $t1, 1348($t0)
    sw $t1, 1476($t0)
    sw $t1, 844($t0)
    sw $t1, 972($t0)
    sw $t1, 1100($t0)
    sw $t1, 1228($t0)
    sw $t1, 1356($t0)
    sw $t1, 1484($t0)
    sw $t1, 852($t0)
    sw $t1, 980($t0)
    sw $t1, 1108($t0)
    sw $t1, 1236($t0)
    sw $t1, 1364($t0)
    sw $t1, 1492($t0)
    sw $t1, 840($t0)
    sw $t1, 848($t0)
    # Letter 'E'
    sw $t1, 860($t0)
    sw $t1, 864($t0)
    sw $t1, 868($t0)
    sw $t1, 872($t0)
    sw $t1, 1244($t0)
    sw $t1, 1248($t0)
    sw $t1, 1252($t0)
    sw $t1, 1500($t0)
    sw $t1, 1504($t0)
    sw $t1, 1508($t0)
    sw $t1, 1512($t0)
    sw $t1, 988($t0)
    sw $t1, 1116($t0)
    sw $t1, 1372($t0)
    #letter 'O'
    sw $t1, 1820($t0)
    sw $t1, 1824($t0)
    sw $t1, 1944($t0)
    sw $t1, 1944($t0)
    sw $t1, 2072($t0)
    sw $t1, 2200($t0)
    sw $t1, 2332($t0)
    sw $t1, 2336($t0)
    sw $t1, 1956($t0)
    sw $t1, 1956($t0)
    sw $t1, 2084($t0)
    sw $t1, 2212($t0)
    #letter 'V'
    sw $t1, 1836($t0)
    sw $t1, 1964($t0)
    sw $t1, 2092($t0)
    sw $t1, 2224($t0)
    sw $t1, 2356($t0)
    sw $t1, 2232($t0)
    sw $t1, 2108($t0)
    sw $t1, 1980($t0)
    sw $t1, 1852($t0)
    #letter 'E'
    sw $t1, 1860($t0)
    sw $t1, 1864($t0)
    sw $t1, 1868($t0)
    sw $t1, 1872($t0)
    sw $t1, 2116($t0)
    sw $t1, 2120($t0)
    sw $t1, 2124($t0)
    sw $t1, 2372($t0)
    sw $t1, 2376($t0)
    sw $t1, 2380($t0)
    sw $t1, 2384($t0)
    sw $t1, 1860($t0)
    sw $t1, 1988($t0)
    sw $t1, 2244($t0)
    #letter 'R'
    sw $t1, 1880($t0)
    sw $t1, 2008($t0)
    sw $t1, 2136($t0)
    sw $t1, 2264($t0)
    sw $t1, 2392($t0)
    sw $t1, 1884($t0)
    sw $t1, 1888($t0)
    sw $t1, 2020($t0)
    sw $t1, 2140($t0)
    sw $t1, 2144($t0)
    sw $t1, 2272($t0)
    sw $t1, 2400($t0)
    sw $t1, 2404($t0)

# Display instruction: press R to retry or Q to quit
wait_for_retry:
    li $v0, 32
    li $a0, 1
    syscall

    lw $t1, ADDR_KBRD
    lw $t2, 0($t1)
    beq $t2, 1, check_retry_input
    j wait_for_retry

check_retry_input:
    lw $a0, 4($t1)
    beq $a0, 0x71, Quit_q        # ASCII 'q'
    beq $a0, 0x72, reset_game    # ASCII 'r'
    j wait_for_retry

reset_game:
     # Clear screen first 
    # $t1 = black (0x000000)
    # $t2 = loop counter (1024 pixels)
    li $t1, 0x000000        # Black color
    li $t2, 0               # Start at pixel 0
    li $t3, 1024            # Total number of pixels
    
    clear_screen_loop2:
        sll $t4, $t2, 2     # Multiply counter by 4 to get byte offset
        add $t5, $t0, $t4   # $t5 = address of pixel
        sw $t1, 0($t5)      # Set pixel to black
        addi $t2, $t2, 1    # Next pixel
        blt $t2, $t3, clear_screen_loop2
        # Reset all global variables to initial values
    li $t1, 0
    sw $t1, First_time
    sw $t1, Capsule_Orientation
    sw $t1, Next_Capsule_Top_Color
    sw $t1, Next_Capsule_Bottom_Color

    # Optional: clear DrMario_Grid
    la $t2, DrMario_Grid
    li $t3, 0
    li $t4, 4096        # 4KB grid
    
clear_loop1:
    beqz $t4, after_clear
    sw $t3, 0($t2)
    addi $t2, $t2, 4
    addi $t4, $t4, -4
    j clear_loop1
    
after_clear:
    # Redraw bottle & reset screen
    j main

toggle_pause:
    lw $t1, Paused
    xori $t1, $t1, 1         # toggle: 0→1, 1→0
    sw $t1, Paused

    beq $t1, 1, begin_paused
    beq $t1, 0, after_paused
    j game_loop              # resume game if unpausing

begin_paused:
    la $t1, Paused_Backup   # destination (RAM)
    move $t2, $t0           # $t0 = base address of bitmap display
    li $t3, 1024            # number of pixels
    li $t4, 0               # counter
    
    save_loop:
        sll $t5, $t4, 2         # byte offset = index × 4
        add $t6, $t0, $t5       # screen pixel address
        add $t7, $t1, $t5       # backup pixel address
    
        lw $t8, 0($t6)
        sw $t8, 0($t7)
    
        addi $t4, $t4, 1
        blt $t4, $t3, save_loop

    # draw "PAUSED" 
    lw $t0, ADDR_DSPL  # $t0 = base address for display
    li $t1, 0xabcdef        # $t1 = special color

    # Pause sound
    li $v0, 31
    li $a0, 50
    li $a1, 500
    li $a2, 34
    li $a3, 30
    syscall
    
    # Paused figure
    sw $t1, 820($t0)
    sw $t1, 948($t0)
    sw $t1, 952($t0)
    sw $t1, 956($t0)
    sw $t1, 1076($t0)
    sw $t1, 1080($t0)
    sw $t1, 1084($t0)
    sw $t1, 1088($t0)
    sw $t1, 1092($t0)
    sw $t1, 1204($t0)
    sw $t1, 1208($t0)
    sw $t1, 1212($t0)
    sw $t1, 1216($t0)
    sw $t1, 1220($t0)
    sw $t1, 1224($t0)
    sw $t1, 1228($t0)
    sw $t1, 1332($t0)
    sw $t1, 1336($t0)
    sw $t1, 1340($t0)
    sw $t1, 1344($t0)
    sw $t1, 1348($t0)
    sw $t1, 1352($t0)
    sw $t1, 1356($t0)
    sw $t1, 1360($t0)
    sw $t1, 1460($t0)
    sw $t1, 1464($t0)
    sw $t1, 1468($t0)
    sw $t1, 1472($t0)
    sw $t1, 1476($t0)
    sw $t1, 1480($t0)
    sw $t1, 1484($t0)
    sw $t1, 1588($t0)
    sw $t1, 1592($t0)
    sw $t1, 1596($t0)
    sw $t1, 1600($t0)
    sw $t1, 1604($t0)
    sw $t1, 1716($t0)
    sw $t1, 1720($t0)
    sw $t1, 1724($t0)
    sw $t1, 1844($t0)
    # letter 'P'
    sw $t1, 2320($t0)
    sw $t1, 2324($t0)
    sw $t1, 2328($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2576($t0)
    sw $t1, 2584($t0)
    sw $t1, 2704($t0)
    sw $t1, 2708($t0)
    sw $t1, 2712($t0)
    sw $t1, 2832($t0)
    sw $t1, 2960($t0)
    sw $t1, 3088($t0)
    # letter 'A'
    sw $t1, 2340($t0)
    sw $t1, 2464($t0)
    sw $t1, 2472($t0)
    sw $t1, 2592($t0)
    sw $t1, 2600($t0)
    sw $t1, 2720($t0)
    sw $t1, 2724($t0)
    sw $t1, 2728($t0)
    sw $t1, 2848($t0)
    sw $t1, 2856($t0)
    sw $t1, 2976($t0)
    sw $t1, 2984($t0)
    sw $t1, 3104($t0)
    sw $t1, 3112($t0)
    # letter 'U'
    sw $t1, 2352($t0)
    sw $t1, 2360($t0)
    sw $t1, 2480($t0)
    sw $t1, 2488($t0)
    sw $t1, 2608($t0)
    sw $t1, 2616($t0)
    sw $t1, 2736($t0)
    sw $t1, 2744($t0)
    sw $t1, 2864($t0)
    sw $t1, 2872($t0)
    sw $t1, 2992($t0)
    sw $t1, 3000($t0)
    sw $t1, 3120($t0)
    sw $t1, 3128($t0)
    sw $t1, 3124($t0)
    # letter 'S'
    sw $t1, 2368($t0)
    sw $t1, 2372($t0)
    sw $t1, 2376($t0)
    sw $t1, 2496($t0)
    sw $t1, 2624($t0)
    sw $t1, 2752($t0)
    sw $t1, 2756($t0)
    sw $t1, 2760($t0)
    sw $t1, 2888($t0)
    sw $t1, 3016($t0)
    sw $t1, 3144($t0)
    sw $t1, 3140($t0)
    sw $t1, 3136($t0)
    # letter' E
    sw $t1, 2384($t0)
    sw $t1, 2388($t0)
    sw $t1, 2392($t0)
    sw $t1, 2512($t0)
    sw $t1, 2640($t0)
    sw $t1, 2768($t0)
    sw $t1, 2772($t0)
    sw $t1, 2776($t0)
    sw $t1, 2896($t0)
    sw $t1, 3024($t0)
    sw $t1, 3152($t0)
    sw $t1, 3156($t0)
    sw $t1, 3160($t0)
    # letter 'D'
    sw $t1, 2400($t0)
    sw $t1, 2404($t0)
    sw $t1, 2408($t0)
    sw $t1, 2528($t0)
    sw $t1, 2656($t0)
    sw $t1, 2540($t0)
    sw $t1, 2668($t0)
    sw $t1, 2784($t0)
    sw $t1, 2796($t0)
    sw $t1, 2912($t0)
    sw $t1, 2924($t0)
    sw $t1, 3040($t0)
    sw $t1, 3052($t0)
    sw $t1, 3168($t0)
    sw $t1, 3172($t0)
    sw $t1, 3176($t0)
    j pause_loop

after_paused:
    li $t1, 0x000000        # Black color
    li $t2, 0               # Start at pixel 0
    li $t3, 1024            # Total number of pixels

    # clean screen first
    clear_screen_loop3:
        sll $t4, $t2, 2     # Multiply counter by 4 to get byte offset
        add $t5, $t0, $t4   # $t5 = address of pixel
        sw $t1, 0($t5)      # Set pixel to black
        addi $t2, $t2, 1    # Next pixel
        blt $t2, $t3, clear_screen_loop3
    la $t1, Paused_Backup
    move $t2, $t0           # $t0 = base address of bitmap display
    li $t3, 1024
    li $t4, 0

restore_loop:
    sll $t5, $t4, 2
    add $t6, $t0, $t5
    add $t7, $t1, $t5

    lw $t8, 0($t7)
    sw $t8, 0($t6)

    addi $t4, $t4, 1
    blt $t4, $t3, restore_loop
    j game_loop

pause_loop:
    li $v0, 32
    li $a0, 1
    syscall

    lw $t2, ADDR_KBRD
    lw $t3, 0($t2)
    beq $t3, 1, pause_check_key
    j pause_loop

pause_check_key:
    lw $a0, 4($t2)
    beq $a0, 0x70, toggle_pause   # 'p'
    j pause_loop

check_delete:
    # initialize Fall_list and Fall_count
    la $t1, Fall_count
    li $t2, 0
    sw $t2, 0($t1)

    # initialize Delete_list and Delete_count
    la $t1, Delete_count
    li $t2, 0
    sw $t2, 0($t1)

    la $t1, Delete_list
    la $t2, Fall_list
    li $t3, 0           # value to write
    li $t4, 128         # number of entries
    li $t5, 0           # loop index
    clean_delete_list:
        bge  $t5, $t4, done_clean
        sll  $t6, $t5, 2      # byte offset = index * 4
        add  $t7, $t1, $t6    # clean Delete_list
        sw   $t3, 0($t7)      # store 0

        add  $t7, $t2, $t6    # clean Fall_list
        sw   $t3, 0($t7)
        addi $t5, $t5, 1
        j clean_delete_list

    done_clean:  
        # The field that we need to detect is top line from 780 to 844, bottom line from 3724 to 3788. 16 * 23 rectangle
        add $t1, $zero, 0   #t1 used to represent the x index
        add $t2, $zero, 0   #t2 used to represent the y index
        j outer_loop_y

    outer_loop_y:
        bge $t2, 24, end_loop
        j inner_loop_x
        inner_loop_x:
            bge $t1, 17, end_inner_loop
            la  $t3, DrMario_Grid       # load DrMario Grid to t3
            mul $t4, $t2, 128           # calculate the real position. y index * 128
            mul $t5, $t1, 4             # x * 4
            add $t4, $t4, $t5           # add x index
            add $t4, $t4, 780           # 780 is the first position in the field that we gonna check
            add $t6, $t3, $t4           # t3 is base of DrMario_Grid
            li  $t5, 0x000000           # t5 is black color
            lw  $a0, 0($t6)             # a0 = color at (x, y)
            beq $a0, $t5, end_col_check # if black, skip
            j check_second_in_row
            
            check_second_in_row:
                add $t5, $t4, 4         # second pixel in the row
                add $t6, $t5, $t3
                lw $a1, 0($t6)          # load pixel 2
                
                bne $a1, $a0, end_row_check
                j check_third_in_row
                
            check_third_in_row:
                add $t6, $t5, 4         # third  pixel in the row
                add $t7, $t6, $t3
                lw $a1, 0($t7)

                bne $a1, $a0, end_row_check
                j check_fourth_in_row

            check_fourth_in_row:
                add $t7, $t6, 4         # fourth pixel in the row
                add $t8, $t7, $t3
                lw $a1, 0($t8)
                
                bne $a1, $a0, end_row_check
                j store_row_in_delete_grid
                
            store_row_in_delete_grid:
                la $t8, Delete_list     # open Delete_Grid
                la $t9, Delete_count    # delete count

                # store the first pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t4, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the second pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t5, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the third pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t6, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the fourth pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t7, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count
    
                j end_row_check
                
            end_row_check:              # when we end row check, we will start column check
                la $t3, DrMario_Grid    # load DrMario Grid to t3
                add $t6, $t3, $t4           # t3 is base of DrMario_Grid
                lw  $a0, 0($t6)             # a0 = color at (x, y)
                j check_second_in_col

            check_second_in_col:
                add $t5, $t4, 128         # second pixel in the col
                add $t6, $t5, $t3
                lw $a1, 0($t6)
                
                bne $a1, $a0, end_col_check
                j check_third_in_col

            check_third_in_col:
                add $t6, $t5, 128         # third  pixel in the col
                add $t7, $t6, $t3
                lw $a1, 0($t7) 
                
                bne $a1, $a0, end_col_check
                j check_fourth_in_col

            check_fourth_in_col:
                add $t7, $t6, 128         # third  pixel in the col
                add $t8, $t7, $t3
                lw $a1, 0($t8)
                
                bne $a1, $a0, end_col_check
                j store_col_in_delete_grid

            store_col_in_delete_grid:
                la $t8, Delete_list     # open Delete_Grid
                la $t9, Delete_count    # delete count

                # store the first pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t4, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the second pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t5, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the third pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t6, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the fourth pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t7, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count
                j end_col_check

            end_col_check:
                add $t1, $t1, 1
                j inner_loop_x
            
        end_inner_loop:
            add $t1, $zero, 0  # reset x index
            add $t2, $t2, 1
            j outer_loop_y

    end_loop:              # define some t 
    lw $t0, ADDR_DSPL      # t0 is the screen
    la $t1, DrMario_Grid   # t1 is DrMario_Grid
    la $t2, Delete_list    # t2 is Delete_list
    la $t4, Delete_count   # t3 is the address of Delete_count
    lw $t3, 0($t4)         # get the number of count
    add $t4, $zero, $zero
    li $t4, 0x000000       # t4 is the black color
    addi $t5, $zero, 0     # index of count 
    j delete_loop

    delete_loop:       # start to delete
        blt $t5, $t3, delete_the_pixel
        j end_delete
        
    delete_the_pixel:
        sll $t6, $t5, 2        # Offset = count × 4 (4 bytes per entry)
        add $t7, $t6, $t2      # Address of delete location
        lw $t8, 0($t7)         # t8 is the position of the deleted pixel
        add $t9, $t1, $t8      # $t9 = address of pixel in DrMario_Grid
        sw $t4, 0($t9)         # draw black on the location in DrMario_Grid
        add $t7, $t0, $t8      # now t9 is the address on screen
        sw $t4, 0($t7)         # draw black on screen
        addi $t5, $t5, 1
        j delete_loop

    end_delete:                # after deletion, we need to put some pixels to fall_list. Those pixels above the deleted pixels.
        la $t1, Delete_list    # t2 is Delete_list
        la $t3, Delete_count   # t3 is the address of Delete_count
        lw $t2, 0($t3)         # get the number of Delete_count
        mul $t2, $t2, 5
        addi $t3, $zero, 0     # t3 is the index of Delete_count
        
        la $t4, Fall_list      # t4 is Fall_list

        la $t9, DrMario_Grid   # t9 is the address of DrMario_Grid
        
        j load_fall_pixel
        
        load_fall_pixel:
            bgt $t3, $t2, end_load_fall_pixel
            sll $t5, $t3, 2      # index times 4
            add $t6, $t5, $t1    # the address of the deleted pixel find in Delete_list
            lw $t7, 0($t6)       # access to the number stored in t6
            j load_right_one_pixel

            load_right_one_pixel:    # the pixel on the right of itself
                add $t7, $t7, 4    # locate the number of the pixel right above the deleted pixel
                bgt $t7, 3788, load_left_one_pixel   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_left_one_pixel  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_left_one_pixel  # if the pixel is white, ignore it and check the next one
    
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_left_one_pixel

            load_left_one_pixel:     # the pixel on the left of itself
                add $t7, $t7, -8     # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_above_pixel   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_above_pixel  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_above_pixel  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_above_pixel
            
            load_above_pixel:        # the pixel above itself
                add $t7, $t7, -124   # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_left_above_pixel   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_left_above_pixel  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_left_above_pixel  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_left_above_pixel

            load_left_above_pixel:   # the pixel on the left above of itself
                add $t7, $t7, -4     # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_right_above_pixel   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_right_above_pixel  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_right_above_pixel  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_right_above_pixel

            load_right_above_pixel:  # the pixel on the right above of itself
                add $t7, $t7, 8      # locate the number of the pixel right above the deleted pixel
                bgt $t7, 3788, next_pixel_load   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, next_pixel_load  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, next_pixel_load  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j next_pixel_load

        next_pixel_load:
            addi $t3, $t3, 1     # index plus one
            j load_fall_pixel
                
        end_load_fall_pixel:
            la $t1, Fall_count   # t1 is the Fall_count
            sw $t3, 0($t1)       # update the Fall_count
            j auto_fall

auto_fall:
    la $t1, DrMario_Grid      # base of the grid
    la $t2, Fall_list         # your list of pixels that need to fall
    la $t4, Fall_count        # number of items to process
    lw $t3, 0($t4)            # load count
    li $t4, 0                 # loop index
    j fall_loop

fall_loop:
    bge $t4, $t3, end_auto_fall

    # Get pixel offset
    sll  $t5, $t4, 2
    add  $t6, $t2, $t5
    lw   $t7, 0($t6)          # $t7 = current pixel offset found in Fall_list
    add  $t8, $t1, $t7
    lw   $t9, 0($t8)          # $t9 = pixel color on DrMario_Grid
    j fall_pixel

fall_pixel:
    addi $t7, $t7, 128        # offset below (next row)
    bge  $t7, 3788, next_pixel   # if out of bounds, skip

    add $t8, $t1, $t7
    lw  $s0, 0($t8)           # color below
    li  $s1, 0x000000
    bne $s0, $s1, next_pixel  # if below is NOT black, stop
    
    # Move pixel down on DrMario_Grid
    sw $s1, -128($t8)         # erase original (draw black on the original position)
    sw $t9, 0($t8)            # draw pixel below

    # Move it down on the screen
    add $t5, $t0, $t7         # the address of the below pixel on the screen
    sw $s1, -128($t5)         # erase
    sw $t9, 0($t5)            # draw it below

    # Wait 0.5 second so player can see the fall
    li $v0, 32
    li $a0, 1
    syscall
    
    # update offset and loop again
    # update the location of the pixel (already undated in the loop)
    j fall_pixel

next_pixel:
    addi $t4, $t4, 1
    j fall_loop

end_auto_fall:
    # la $t1, Check_delete_count   # how many time we have check deletion
    # addi $t2, $t1, 1             # add 1
    # sw $t2, 0($t1)               # store the new value to Check_delete_count
    # li $t3, 2                    # set the time we want repeat check deletion
    # ble $t1, $t3, check_game_over   # check deletion again
    # li $t2, 0                    # set t2 to 0
    # lw $t2, 0($t1)               # reset delete Check_delete_count to 0
    j check_delete2

check_delete2:
    # initialize Fall_list and Fall_count
    la $t1, Fall_count
    li $t2, 0
    sw $t2, 0($t1)

    # initialize Delete_list and Delete_count
    la $t1, Delete_count
    li $t2, 0
    sw $t2, 0($t1)

    la $t1, Delete_list
    la $t2, Fall_list
    li $t3, 0           # value to write
    li $t4, 128         # number of entries
    li $t5, 0           # loop index
    clean_delete_list2:
        bge  $t5, $t4, done_clean2
        sll  $t6, $t5, 2      # byte offset = index * 4
        add  $t7, $t1, $t6    # clean Delete_list
        sw   $t3, 0($t7)      # store 0

        add  $t7, $t2, $t6    # clean Fall_list
        sw   $t3, 0($t7)
        addi $t5, $t5, 1
        j clean_delete_list2

    done_clean2:  
        # The field that we need to detect is top line from 780 to 844, bottom line from 3724 to 3788. 16 * 23 rectangle
        add $t1, $zero, 0   #t1 used to represent the x index
        add $t2, $zero, 0   #t2 used to represent the y index
        j outer_loop_y2

    outer_loop_y2:
        bge $t2, 24, end_loop2
        j inner_loop_x2
        inner_loop_x2:
            bge $t1, 17, end_inner_loop2
            la  $t3, DrMario_Grid       # load DrMario Grid to t3
            mul $t4, $t2, 128           # calculate the real position. y index * 128
            mul $t5, $t1, 4             # x * 4
            add $t4, $t4, $t5           # add x index
            add $t4, $t4, 780           # 780 is the first position in the field that we gonna check
            add $t6, $t3, $t4           # t3 is base of DrMario_Grid
            li  $t5, 0x000000           # t5 is black color
            lw  $a0, 0($t6)             # a0 = color at (x, y)
            beq $a0, $t5, end_col_check2 # if black, skip
            j check_second_in_row2
            
            check_second_in_row2:
                add $t5, $t4, 4         # second pixel in the row
                add $t6, $t5, $t3
                lw $a1, 0($t6)          # load pixel 2
                
                bne $a1, $a0, end_row_check2
                j check_third_in_row2
                
            check_third_in_row2:
                add $t6, $t5, 4         # third  pixel in the row
                add $t7, $t6, $t3
                lw $a1, 0($t7)

                bne $a1, $a0, end_row_check2
                j check_fourth_in_row2

            check_fourth_in_row2:
                add $t7, $t6, 4         # fourth pixel in the row
                add $t8, $t7, $t3
                lw $a1, 0($t8)
                
                bne $a1, $a0, end_row_check2
                j store_row_in_delete_grid2
                
            store_row_in_delete_grid2:
                la $t8, Delete_list     # open Delete_Grid
                la $t9, Delete_count    # delete count

                # store the first pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t4, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the second pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t5, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the third pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t6, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the fourth pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t7, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count
    
                j end_row_check2
                
            end_row_check2:              # when we end row check, we will start column check
                la $t3, DrMario_Grid    # load DrMario Grid to t3
                add $t6, $t3, $t4           # t3 is base of DrMario_Grid
                lw  $a0, 0($t6)             # a0 = color at (x, y)
                j check_second_in_col2

            check_second_in_col2:
                add $t5, $t4, 128         # second pixel in the col
                add $t6, $t5, $t3
                lw $a1, 0($t6)
                
                bne $a1, $a0, end_col_check2
                j check_third_in_col2

            check_third_in_col2:
                add $t6, $t5, 128         # third  pixel in the col
                add $t7, $t6, $t3
                lw $a1, 0($t7) 
                
                bne $a1, $a0, end_col_check2
                j check_fourth_in_col2

            check_fourth_in_col2:
                add $t7, $t6, 128         # third  pixel in the col
                add $t8, $t7, $t3
                lw $a1, 0($t8)
                
                bne $a1, $a0, end_col_check2
                j store_col_in_delete_grid2

            store_col_in_delete_grid2:
                la $t8, Delete_list     # open Delete_Grid
                la $t9, Delete_count    # delete count

                # store the first pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t4, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the second pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t5, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the third pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t6, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count

                # store the fourth pixel's location into Delete_list
                lw   $t3, 0($t9)        # Load current count
                sll  $t3, $t3, 2        # Offset = count × 4 (4 bytes per entry)
                add  $t3, $t3, $t8      # Address of next free slot
                sw   $t7, 0($t3)        # Store the value (996) into the list
                lw   $t3, 0($t9)        # Load current count
                addi $t3, $t3, 1        # count++
                sw   $t3, 0($t9)        # Update Delete_List_Count
                j end_col_check2

            end_col_check2:
                add $t1, $t1, 1
                j inner_loop_x2
            
        end_inner_loop2:
            add $t1, $zero, 0  # reset x index
            add $t2, $t2, 1
            j outer_loop_y2

    end_loop2:              # define some t 
    lw $t0, ADDR_DSPL      # t0 is the screen
    la $t1, DrMario_Grid   # t1 is DrMario_Grid
    la $t2, Delete_list    # t2 is Delete_list
    la $t4, Delete_count   # t3 is the address of Delete_count
    lw $t3, 0($t4)         # get the number of count
    add $t4, $zero, $zero
    li $t4, 0x000000       # t4 is the black color
    addi $t5, $zero, 0     # index of count 
    j delete_loop2

    delete_loop2:       # start to delete
        blt $t5, $t3, delete_the_pixel2
        j end_delete2
        
    delete_the_pixel2:
        sll $t6, $t5, 2        # Offset = count × 4 (4 bytes per entry)
        add $t7, $t6, $t2      # Address of delete location
        lw $t8, 0($t7)         # t8 is the position of the deleted pixel
        add $t9, $t1, $t8      # $t9 = address of pixel in DrMario_Grid
        sw $t4, 0($t9)         # draw black on the location in DrMario_Grid
        add $t7, $t0, $t8      # now t9 is the address on screen
        sw $t4, 0($t7)         # draw black on screen
        addi $t5, $t5, 1
        j delete_loop2

    end_delete2:                # after deletion, we need to put some pixels to fall_list. Those pixels above the deleted pixels.
        la $t1, Delete_list    # t2 is Delete_list
        la $t3, Delete_count   # t3 is the address of Delete_count
        lw $t2, 0($t3)         # get the number of Delete_count
        mul $t2, $t2, 5
        addi $t3, $zero, 0     # t3 is the index of Delete_count
        
        la $t4, Fall_list      # t4 is Fall_list

        la $t9, DrMario_Grid   # t9 is the address of DrMario_Grid
        
        j load_fall_pixel2
        
        load_fall_pixel2:
            bgt $t3, $t2, end_load_fall_pixel2
            sll $t5, $t3, 2      # index times 4
            add $t6, $t5, $t1    # the address of the deleted pixel find in Delete_list
            lw $t7, 0($t6)       # access to the number stored in t6
            j load_right_one_pixel2

            load_right_one_pixel2:    # the pixel on the right of itself
                add $t7, $t7, 4    # locate the number of the pixel right above the deleted pixel
                bgt $t7, 3788, load_left_one_pixel2   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_left_one_pixel2  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_left_one_pixel2  # if the pixel is white, ignore it and check the next one
    
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_left_one_pixel2

            load_left_one_pixel2:     # the pixel on the left of itself
                add $t7, $t7, -8     # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_above_pixel2   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_above_pixel2  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_above_pixel2  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_above_pixel2
            
            load_above_pixel2:        # the pixel above itself
                add $t7, $t7, -124   # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_left_above_pixel2   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_left_above_pixel2  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_left_above_pixel2  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_left_above_pixel2

            load_left_above_pixel2:   # the pixel on the left above of itself
                add $t7, $t7, -4     # locate the number of the pixel right above the deleted pixel
                blt $t7, 780, load_right_above_pixel2   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, load_right_above_pixel2  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, load_right_above_pixel2  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j load_right_above_pixel2

            load_right_above_pixel2:  # the pixel on the right above of itself
                add $t7, $t7, 8      # locate the number of the pixel right above the deleted pixel
                bgt $t7, 3788, next_pixel_load2   # skip if above top
                add $t6, $t7, $t9    # location on DrMario_Grid
                lw $t8, 0($t6)       # access the pixel on t6
                li $t6, 0x000000     # black pixel
                beq $t8, $t6, next_pixel_load2  # if the pixel is black, ignore it and check the next one
                li $t6, 0xffffff     # white pixel
                beq $t8, $t6, next_pixel_load2  # if the pixel is white, ignore it and check the next one
    
                addi $t3, $t3, 1
                sll $t5, $t3, 2
                add $t8, $t5, $t4    # the linked location on Fall_list
                sw  $t7, 0($t8)
                j next_pixel_load2

        next_pixel_load2:
            addi $t3, $t3, 1     # index plus one
            j load_fall_pixel2
                
        end_load_fall_pixel2:
            la $t1, Fall_count   # t1 is the Fall_count
            sw $t3, 0($t1)       # update the Fall_count
            j auto_fall2

auto_fall2:
    la $t1, DrMario_Grid      # base of the grid
    la $t2, Fall_list         # your list of pixels that need to fall
    la $t4, Fall_count        # number of items to process
    lw $t3, 0($t4)            # load count
    li $t4, 0                 # loop index
    j fall_loop2

fall_loop2:
    bge $t4, $t3, end_auto_fall2

    # Get pixel offset
    sll  $t5, $t4, 2
    add  $t6, $t2, $t5
    lw   $t7, 0($t6)          # $t7 = current pixel offset found in Fall_list
    add  $t8, $t1, $t7
    lw   $t9, 0($t8)          # $t9 = pixel color on DrMario_Grid
    j fall_pixel2

fall_pixel2:
    addi $t7, $t7, 128        # offset below (next row)
    bge  $t7, 3788, next_pixel2   # if out of bounds, skip

    add $t8, $t1, $t7
    lw  $s0, 0($t8)           # color below
    li  $s1, 0x000000
    bne $s0, $s1, next_pixel2  # if below is NOT black, stop
    
    # Move pixel down on DrMario_Grid
    sw $s1, -128($t8)         # erase original (draw black on the original position)
    sw $t9, 0($t8)            # draw pixel below

    # Move it down on the screen
    add $t5, $t0, $t7         # the address of the below pixel on the screen
    sw $s1, -128($t5)         # erase
    sw $t9, 0($t5)            # draw it below

    # Wait 0.5 second so player can see the fall
    li $v0, 32
    li $a0, 1
    syscall
    
    # update offset and loop again
    # update the location of the pixel (already undated in the loop)
    j fall_pixel2

next_pixel2:
    addi $t4, $t4, 1
    j fall_loop2

end_auto_fall2:
    j generate_capsule

game_loop:
     # 1. Enable keyboard input
    li $v0, 32
    li $a0, 1
    syscall
    
    # 1a. Check if key has been pressed
    lw $t1, ADDR_KBRD # $t0 = base address for bitmap & t1 = base address for keyboard
    lw $t2, 0($t1) # Load first word from keyboard to $t1
    beq $t2, 1, keyboard_input # If first word 1, key is pressed

    # Easy feature 1: implement gravity
    # Initialize real time
    li $v0, 30           # Load syscall code 30 (get time in ms)
    syscall              # Trigger syscall
    move $t4, $a0        # $t4 = current time in ms
    lw $t5, Gravity_Time # Load last gravity time
    sub $t6, $t4, $t5    # elapsed = now - last_time

    # Hard Feature 1: Background music
    # Play mario theme song
    lw $t1, current_pause_remaining
    bgtz $t1, skip_note_play
    jal play_next_note
    j after_note_check

    skip_note_play:
        addi $t1, $t1, -1
        sw $t1, current_pause_remaining
        
    after_note_check:
    # End of background music

    # Easy feature 2: increase gravity 
    # Load repeat count and calculate dynamic delay, speed increases 20ms pre capsule
    lw $t3, Repeat_time
    sll $t4, $t3, 4      # $t4 = t3 * 16
    sll $t5, $t3, 2      # $t5 = t3 * 4
    add $t3, $t4, $t5    # $t3 = (t3 * 16) + (t3 * 4) = t3 * 20
    li $t4, 1000
    sub $t5, $t4, $t3    # $t5 = 1000 - Repeat_time
    
    # Clamp minimum delay: the fastest speed is 200ms
    li $t7, 200
    bge $t5, $t7, increased_time
    j max_speed

    max_speed:
        bge $t6, $t7, gravity
        j game_loop
    
    increased_time:
        bge $t6, $t5, gravity   # if elapsed time reaches the gravity time, move down and reset gravity_time
        j game_loop
    
    j game_loop

    # 1b. Check which key has been pressed
    keyboard_input: # A key is pressed
        lw $a0, 4($t1) # Load second word from keyboard
        beq $a0, 0x71, Quit_q # Check if the key q was pressed
        beq $a0, 0x73, Move_Down_s # Check if the key s was pressed
        beq $a0, 0x61, Move_Left_a # Check if the key a was pressed
        beq $a0, 0x64, Move_Right_d # Check if the key d was pressed
        beq $a0, 0x77, Rotate_Clockwise_w # Check if the key w was pressed
        beq $a0, 0x70, toggle_pause   # Check if the key p was pressed
        j game_loop
        
    gravity:
        move $t4, $a0  
        sw $t4, Gravity_Time #reset timer
        j Move_Down_s
    
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep
    # li $v0, 32       # Syscall 32 = sleep
    # li $a0, 1000     # Sleep time = 1000 milliseconds (1 second)
    # syscall          # Call the sleep syscall
    # 5. Go back to Step 1
    j game_loop
