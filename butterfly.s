# Butterfly operation using vrgather instead of slide instructions
# Inputs:
#   a0: x[idx1] (A) - address of [real, imag]
#   a1: x[idx2] (B) - address of [real, imag]
#   a2: W (twiddle) - address of [real, imag]

.section .text
.global butterfly
.align 2
butterfly:
    # Configure for 2 elements (1 complex number)
    vsetivli zero, 2, e32, m1, ta, ma

    # Load complex numbers
    vle32.v v1, (a0)       # v1 = [A_real, A_imag]
    vle32.v v2, (a1)       # v2 = [B_real, B_imag]
    vle32.v v3, (a2)       # v3 = [W_real, W_imag]

    # Compute component products
    vfmul.vv v4, v2, v3    # v4 = [B_real*W_real, B_imag*W_imag]
    vrgather.vi v5, v3, 1   # v5 = [W_imag, W_real] (swap)
    vfmul.vv v6, v2, v5    # v6 = [B_real*W_imag, B_imag*W_real]

    # Real part: B_real*W_real - B_imag*W_imag
    vrgather.vi v7, v4, 1   # v7 = [B_imag*W_imag, B_real*W_real]
    vfneg.v v7, v7          # v7 = [-B_imag*W_imag, -B_real*W_real]
    vfadd.vv v8, v4, v7     # v8 = [real(W*B), garbage]

    # Imag part: B_real*W_imag + B_imag*W_real
    vrgather.vi v9, v6, 1   # v9 = [B_imag*W_real, B_real*W_imag]
    vfadd.vv v10, v6, v9    # v10 = [imag(W*B), garbage]

    # Combine real and imag parts using vrgather instead of slides
    vmv.v.i v11, 0          # Clear v11
    vrgather.vi v12, v8, 1  # v12 = [v8[1], v8[1]] (broadcast real)
    vrgather.vi v13, v10, 1 # v13 = [v10[1], v10[1]] (broadcast imag)
    vmerge.vvm v11, v12, v13, v0  # v11 = [real, imag] (if mask is [0,1])

    # Alternative merge without mask (requires VL=2)
    vrgather.vi v11, v8, 1   # v11 = [real, real]
    vrgather.vi v14, v10, 1  # v14 = [imag, imag]
    vsll.vi v14, v14, 1      # Shift to get [0, imag] (assuming SEW=32)
    vor.vv v11, v11, v14     # v11 = [real, imag]

    # Butterfly operations
    vfadd.vv v12, v1, v11   # A' = A + W*B
    vfsub.vv v13, v1, v11   # B' = A - W*B

    # Store results
    vse32.v v12, (a0)
    vse32.v v13, (a1)

    ret
