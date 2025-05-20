# Inputs:

#   a0 - W_real output array pointer

#   a1 - W_imag output array pointer

#   a2 - FFT size N (must be power of 2)

# Uses:

#   v1-v30 vector registers

#   ft0-ft7 floating-point temporaries



compute_twiddle_factors:

    addi sp, sp, -32

    sd ra, 0(sp)

    sd a0, 8(sp)      # Save W_real pointer

    sd a1, 16(sp)     # Save W_imag pointer

    sd a2, 24(sp)     # Save N



    # Calculate N/2 and set vector length

    srli a4, a2, 1    # a4 = N/2

    vsetvli t1, a4, e32, m8  # Process elements as 32-bit floats



    # Load constants (more precise versions)

    la t0, sincos_constants

    # High precision π/2 (split into hi and lo parts)

    flw ft0, 0(t0)    # π/2_hi = 1.570796251296997

    flw ft1, 4(t0)    # π/2_lo = 7.549789415861596e-8

    flw ft2, 8(t0)    # 1/(2π) = 0.159154943091895

    flw ft3, 12(t0)   # 12582912.0 (magic number for range reduction)

    flw ft4, 16(t0)   # -2π (exact value)

    

    # Polynomial coefficients

    flw ft5, 20(t0)   # cos_coeff_0 = 2.44677067e-5

    flw ft6, 24(t0)   # cos_coeff_1 = -1.38877297e-3

    flw ft7, 28(t0)   # cos_coeff_2 = 4.16666567e-2

    flw ft8, 32(t0)   # cos_coeff_3 = -0.5

    flw ft9, 36(t0)   # cos_coeff_4 = 1.0

    flw ft10, 40(t0)  # sin_coeff_0 = 2.86567956e-6

    flw ft11, 44(t0)  # sin_coeff_1 = -1.98559923e-4

    flw ft12, 48(t0)  # sin_coeff_2 = 8.33338592e-3

    flw ft13, 52(t0)  # sin_coeff_3 = -0.166666672



    # Calculate -2π/N

    fcvt.s.w ft14, a2  # Convert N to float

    fdiv.s ft15, ft4, ft14  # ft15 = -2π/N



    # Initialize vector indices

    vid.v v2          # [0, 1, 2, ... VLEN-1]

    li t0, 0          # Loop counter

    slli t2, t1, 2    # t2 = VLEN * 4 (byte stride)



    # Move constants to vector registers

    vfmv.v.f v1, ft0  # π/2_hi

    vfmv.v.f v20, ft1 # π/2_lo

    vfmv.v.f v3, ft2  # 1/(2π)

    vfmv.v.f v4, ft3  # 12582912.0

    vfmv.v.f v5, ft5  # cos coeffs

    vfmv.v.f v6, ft6

    vfmv.v.f v7, ft7

    vfmv.v.f v8, ft8

    vfmv.v.f v9, ft9

    vfmv.v.f v10, ft10 # sin coeffs

    vfmv.v.f v11, ft11

    vfmv.v.f v12, ft12

    vfmv.v.f v13, ft13



vsincos_loop:

    bge t0, a4, vsincos_end  # Loop until all twiddles computed



    # Convert indices to angles θ = -2πk/N

    vfcvt.f.x.v v21, v2      # Convert indices to float

    vfmul.vf v21, v21, ft15  # Multiply by -2π/N

    

    # Range reduction: θ = j*(π/2) + a, where |a| ≤ π/4

    # 1. Compute j = round(θ/(π/2)) using magic number method

    vmv.v.v v15, v4          # Load magic number 12582912.0

    vfmacc.vv v15, v21, v3   # j = θ*(1/(2π)) + magic

    vfsub.vv v15, v15, v4    # j = j - magic = θ/(π/2) rounded

    

    # 2. Compute a = θ - j*(π/2) using two-part π/2

    vfnmsac.vv v21, v15, v1  # a = θ - j*π/2_hi

    vfnmsac.vv v21, v15, v20 # a = a - j*π/2_lo

    

    # Convert j to integer for quadrant analysis

    vfcvt.x.f.v v26, v15     # Integer j

    vadd.vi v22, v26, 1      # j+1 for cosine phase



    # Compute polynomial approximations

    vfmul.vv v17, v21, v21   # a²

    vfmul.vv v18, v21, v17   # a³

    

    # Cosine approximation: 1 - a²/2! + a⁴/4! - ...

    vmv.v.v v14, v5          # Start with c5

    vfmadd.vv v14, v17, v6   # c5*a² + c4

    vfmadd.vv v14, v17, v7   # (c5*a² + c4)*a² + c3

    vfmadd.vv v14, v17, v8   # ... + c2

    vfmadd.vv v14, v17, v9   # ... + c1 → final cos(a)

    

    # Sine approximation: a - a³/3! + a⁵/5! - ...

    vmv.v.v v24, v10         # Start with s4

    vfmadd.vv v24, v17, v11  # s4*a² + s3

    vfmadd.vv v24, v17, v12  # (s4*a² + s3)*a² + s2

    vfmadd.vv v24, v17, v13  # ... + s1

    vfmadd.vv v24, v18, v21  # ...*a³ + a → final sin(a)



    # Quadrant adjustment:

    # For odd j: swap sin/cos and adjust signs

    vand.vi v0, v26, 1       # Mask for odd j

    vmseq.vi v0, v0, 1

    

    # Merge results with quadrant handling

    vmerge.vvm v28, v24, v14, v0  # sin = odd? cos(a) : sin(a)

    vmerge.vvm v30, v14, v24, v0  # cos = odd? sin(a) : cos(a)

    

    # Sign correction based on quadrant

    vand.vi v0, v26, 2       # Check if j mod 4 ≥ 2

    vmseq.vi v0, v0, 2

    vfsgnjn.vv v28, v28, v28, v0  # Negate sin if needed

    

    vand.vi v0, v22, 2       # Check if (j+1) mod 4 ≥ 2

    vmseq.vi v0, v0, 2

    vfsgnjn.vv v30, v30, v30, v0  # Negate cos if needed



    # Store twiddle factors

    vse32.v v30, (a0)        # Store real parts (cos)

    vse32.v v28, (a1)        # Store imag parts (sin)

    

    # Update pointers and indices

    add t0, t0, t1           # k += VLEN

    add a0, a0, t2           # Advance real pointer

    add a1, a1, t2           # Advance imag pointer

    vadd.vx v2, v2, t1       # Increment indices

    j vsincos_loop



vsincos_end:

    # Restore registers

    ld ra, 0(sp)

    ld a0, 8(sp)

    ld a1, 16(sp)

    ld a2, 24(sp)

    addi sp, sp, 32

    ret



.section .rodata

.align 4

sincos_constants:

    # High precision π/2 split into hi and lo parts

    .float 1.570796251296997     # π/2_hi

    .float 7.549789415861596e-8  # π/2_lo

    .float 0.159154943091895     # 1/(2π)

    .float 12582912.0            # Magic number for range reduction

    .float -6.283185307179586    # -2π

    

    # Polynomial coefficients for cos(x)

    .float 2.44677067e-5         # c5

    .float -1.38877297e-3        # c4

    .float 4.16666567e-2         # c3

    .float -0.5                  # c2

    .float 1.0                   # c1

    

    # Polynomial coefficients for sin(x)

    .float 2.86567956e-6         # s4

    .float -1.98559923e-4        # s3

    .float 8.33338592e-3         # s2

    .float -0.166666672          # s1