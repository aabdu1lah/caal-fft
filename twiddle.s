# RV32GCV Twiddle Factor Computation (Compatible Version)
# Uses only basic vector instructions supported by most implementations

.text
.global _start

_start:
    # Set up test parameters
    la a0, W_real       # Output array for real parts
    la a1, W_imag       # Output array for imaginary parts
    li a2, 32           # FFT size N (power of 2)

    jal compute_twiddle_factors

    # Exit
    li a7, 93           # Exit syscall number
    li a0, 0            # Exit code 0
    ecall

compute_twiddle_factors:
    addi sp, sp, -16
    sw ra, 0(sp)
    sw a0, 4(sp)        # Save W_real pointer
    sw a1, 8(sp)        # Save W_imag pointer
    sw a2, 12(sp)       # Save N

    # Calculate N/2 and set vector length
    srli a4, a2, 1      # a4 = N/2
    vsetvli t0, a4, e32, m4  # Use m4 instead of m8 for better compatibility

    # Load constants
    lui t1, %hi(sincos_constants)
    addi t1, t1, %lo(sincos_constants)

    # Load PI/2 and other constants
    flw ft0, 0(t1)      # PI/2
    flw ft1, 4(t1)      # 1.0
    flw ft2, 8(t1)      # -2.0
    flw ft3, 12(t1)     # 0.5
    flw ft4, 16(t1)     # 2*PI
    flw ft5, 20(t1)     # Magic number for range reduction

    # Calculate -2*PI/N
    fcvt.s.w ft6, a2    # Convert N to float
    fdiv.s ft7, ft4, ft6 # 2*PI/N
    fneg.s ft7, ft7     # -2*PI/N

    # Initialize vector indices
    vid.v v0           # [0, 1, 2, ... VLEN-1]
    vmv.v.i v1, 0      # Zero register

    # Convert indices to float and compute angles
    vfcvt.f.x.v v2, v0
    vfmul.vf v2, v2, ft7 # v2 = -2*PI*k/N

    # Range reduction
    vfmul.vf v3, v2, ft5
    vfcvt.x.f.v v4, v3  # j = round(theta / (PI/2))
    vfcvt.f.x.v v5, v4
    vfnmsac.vf v2, ft0, v5 # a = theta - j*(PI/2)

    # Compute a^2
    vfmul.vv v6, v2, v2

    # Evaluate sin(a) polynomial
    flw ft8, 24(t1)    # c1 = -1/6
    flw ft9, 28(t1)    # c2 = 1/120
    vfmv.v.f v7, ft8
    vfmacc.vf v7, ft9, v6
    vfmul.vv v7, v7, v6
    vfadd.vf v7, v7, ft1
    vfmul.vv v7, v7, v2

    # Evaluate cos(a) polynomial
    flw ft10, 32(t1)   # c3 = -1/2
    flw ft11, 36(t1)   # c4 = 1/24
    vfmv.v.f v8, ft10
    vfmacc.vf v8, ft11, v6
    vfmul.vv v8, v8, v6
    vfadd.vf v8, v8, ft1

    # Quadrant adjustment (using basic instructions)
    # Instead of vmerge, we'll use arithmetic operations
    vand.vi v9, v4, 1  # Mask for odd quadrants

    # Create selection masks
    vfcvt.f.x.v v9, v9 # Convert mask to float (0.0 or 1.0)
    vfsub.vf v10, v9, ft1 # -1.0 or 0.0
    vfabs.v v10, v10   # 1.0 or 0.0

    # Select between sin and cos using arithmetic
    vfmul.vv v11, v7, v10   # sin(a) * mask
    vfsub.vv v12, v1, v10   # 1.0 - mask
    vfmul.vv v13, v8, v12   # cos(a) * (1-mask)
    vfadd.vv v14, v11, v13  # Combined result

    # Do the same for the other term
    vfmul.vv v15, v8, v10   # cos(a) * mask
    vfmul.vv v16, v7, v12   # sin(a) * (1-mask)
    vfadd.vv v17, v15, v16  # Combined result

    # Sign correction (basic implementation)
    vand.vi v18, v4, 2     # Check sign bit
    vmsne.vi v0, v18, 0    # Set mask register
    vfsgnjx.vv v19, v14, v14 # Absolute value
    vfsgnjn.vv v20, v14, v14 # Negative absolute value
    vmerge.vvm v21, v19, v20, v0 # Select based on mask

    vadd.vi v22, v4, 1     # j+1 for cosine
    vand.vi v22, v22, 2    # Check sign bit
    vmsne.vi v0, v22, 0    # Set mask register
    vfsgnjx.vv v23, v17, v17 # Absolute value
    vfsgnjn.vv v24, v17, v17 # Negative absolute value
    vmerge.vvm v25, v23, v24, v0 # Select based on mask

    # Store results
    vse32.v v25, (a0)     # Store real parts (cos)
    vse32.v v21, (a1)     # Store imag parts (sin)

    # Restore registers
    lw ra, 0(sp)
    lw a0, 4(sp)
    lw a1, 8(sp)
    lw a2, 12(sp)
    addi sp, sp, 16
    ret

.section .rodata
.align 4
sincos_constants:
    .float 1.5707963267948966    # PI/2
    .float 1.0
    .float -2.0
    .float 0.5
    .float 6.283185307179586     # 2*PI
    .float 2670177.939259        # 2^23/(PI/2)
    .float -0.16666666666666666  # -1/6
    .float 0.008333333333333333  # 1/120
    .float -0.5                  # -1/2
    .float 0.041666666666666664  # 1/24

.section .bss
.align 4
W_real: .space 128  # Space for real parts
W_imag: .space 128  # Space for imaginary parts