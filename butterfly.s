# Input: 

#   a0 = &data[i], a1 = &data[i + N/2], a2 = twiddle (W_N^k)

#   v1 = [A_real, A_imag], v2 = [B_real, B_imag], v3 = [W_real, W_imag]

# Output: 

#   [A' = A + W*B, B' = A - W*B] stored back to memory



butterfly:
    # Load complex numbers (2x 32-bit floats)
    vle32.v v1, (a0)       # v1 = [A_real, A_imag]
    vle32.v v2, (a1)       # v2 = [B_real, B_imag]
    vle32.v v3, (a2)       # v3 = [W_real, W_imag]



    # Complex multiply: W*B = (W_real + jW_imag)(B_real + jB_imag)

    # Temp registers: v4-v7

    vfmul.vv v4, v2, v3            # v4 = [B_real*W_real, B_imag*W_real]
    vfrsub.vf v5, v3, 0            # v5 = [-W_real, -W_real] (for cross terms)
    vfmul.vv v6, v2, v3            # v6 = [B_real*W_imag, B_imag*W_imag]
    vfsgnj.vv v7, v2, v2           # v7 = [B_real, B_imag] (copy)



    # Real part: B_real*W_real - B_imag*W_imag

    vfredsum.vs v4, v4, v5         # v4 = [B_real*W_real - B_imag*W_imag, ...]



    # Imag part: B_real*W_imag + B_imag*W_real

    vfredsum.vs v6, v6, v7         # v6 = [B_real*W_imag + B_imag*W_real, ...]



    # Combine results

    vslideup.vi v8, v4, 1          # v8 = [real(W*B), 0]
    vslideup.vi v9, v6, 1          # v9 = [imag(W*B), 0]
    vor.vv v10, v8, v9             # v10 = [real(W*B), imag(W*B)]



    # Butterfly operations

    vfadd.vv v11, v1, v10          # A' = A + W*B
    vfsub.vv v12, v1, v10          # B' = A - W*B



    # Store results

    vse32.v v11, (a0)
    vse32.v v12, (a1)

    ret