bit_reverse_array:

    # Now computes indices dynamically

    addi sp, sp, -32

    sd ra, 0(sp)

    sd s0, 8(sp)

    sd s1, 16(sp)

    

    mv s0, a0           # array pointer

    li s1, 1024         # N=1024

    

    # Calculate log2(N)

    li t0, 0

    li t1, 1

bit_count:

    slli t1, t1, 1

    addi t0, t0, 1

    blt t1, s1, bit_count

    

    # Vector config

    vsetivli zero, 4, e32, m1, ta, ma

li t2, 0            # i = 0

bit_rev_loop:

    bge t2, s1, bit_rev_done

    

    # Compute reversed index

    mv a0, t2

    mv a1, t0

    call reverse_bits

    

    # Only swap if i < reversed_i

    bge t2, a0, no_swap

    

    # Load both elements

    slli t3, t2, 3      # i*8 (complex)

    add t4, s0, t3

    vle32.v v0, (t4)

    

    slli t3, a0, 3      # rev_i*8

    add t5, s0, t3

    vle32.v v1, (t5)

    

    # Swap

    vse32.v v0, (t5)

    vse32.v v1, (t4)

no_swap:

    addi t2, t2, 1

    j bit_rev_loop

    

bit_rev_done:

    ld ra, 0(sp)

    ld s0, 8(sp)

    ld s1, 16(sp)

    addi sp, sp, 32

    ret



reverse_bits:

    # a0=number, a1=bit_count

    mv t0, a0

    li a0, 0

    li t1, 0

rev_loop:

    beqz a1, rev_done

    srli t2, t0, 1

    andi t3, t0, 1

    slli a0, a0, 1

    or a0, a0, t3

    mv t0, t2

    addi a1, a1, -1

    j rev_loop

rev_done:

    ret