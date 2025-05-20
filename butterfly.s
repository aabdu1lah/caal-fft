# Butterfly operation for Radix-2 FFT (RV32GCV)
# Inputs:
#   a0: x[idx1] (A) address (complex float: [real, imag])
#   a1: x[idx2] (B) address (complex float: [real, imag])
#   a2: W (twiddle factor) address (complex float: [real, imag])
# VLEN >= 64 bits (2x 32-bit floats)

.section .text
.global butterfly
.align 2
butterfly:
    # Configure vector length for 1 complex number (2 floats)
    vsetivli zero, 2, e32, m1, ta, ma

    # Load complex numbers
    vle32.v v1, (a0)       # v1 = [A_real, A_imag]
    vle32.v v2, (a1)       # v2 = [B_real, B_imag]
    vle32.v v3, (a2)       # v3 = [W_real, W_imag]

    # Compute component-wise products
    vfmul.vv v4, v2, v3    # v4 = [B_real*W_real, B_imag*W_imag]
    vrgather.vi v5, v3, 1   # v5 = [W_imag, W_real]
    vfmul.vv v6, v2, v5    # v6 = [B_real*W_imag, B_imag*W_real]

    # Real part: B_real*W_real - B_imag*W_imag
    vrgather.vi v7, v4, 1   # v7 = [B_imag*W_imag, B_real*W_real]
    vfneg.v v7, v7          # REPLACEMENT: v7 = -[B_imag*W_imag, ...]
    vfadd.vv v8, v4, v7     # v8 = [real(W*B), garbage]

    # Imag part: B_real*W_imag + B_imag*W_real
    vrgather.vi v9, v6, 1   # v9 = [B_imag*W_real, B_real*W_imag]
    vfadd.vv v10, v6, v9    # v10 = [imag(W*B), garbage]

    # Combine real and imag parts
    vfmv.s.f v11, zero      # Clear v11
    vfslide1down.vf v11, v8, zero   # Extract real part
    vfslide1down.vf v12, v10, zero  # Extract imag part
    vfslide1up.vf v11, v12          # v11 = [real(W*B), imag(W*B)]

    # Butterfly operations (A' = A + W*B, B' = A - W*B)
    vfadd.vv v12, v1, v11   # A' = A + W*B
    vfneg.v v13, v11        # REPLACEMENT: v13 = -W*B
    vfadd.vv v13, v1, v13   # B' = A - W*B

    # Store results
    vse32.v v12, (a0)
    vse32.v v13, (a1)

    ret