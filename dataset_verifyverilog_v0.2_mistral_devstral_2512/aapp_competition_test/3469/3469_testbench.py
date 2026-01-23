import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np
import math

# Helper to convert float to Q16.16
def float_to_q16_16(f):
    return int(f * 65536)

def q16_16_to_float(q):
    return q / 65536.0

# Helper to build KMP automaton transitions
# Returns matrix of size (len+1) x 2 (0='T', 1='H')
def build_kmp(pattern_str):
    m = len(pattern_str)
    pattern = [1 if c == 'H' else 0 for c in pattern_str]
    
    # Compute prefix function pi
    pi = [0] * (m + 1)
    for i in range(1, m):
        j = pi[i]
        while j > 0 and pattern[i] != pattern[j]:
            j = pi[j]
        if pattern[i] == pattern[j]:
            j += 1
        pi[i+1] = j
    
    # Build transition table
    trans = [[0] * 2 for _ in range(m + 1)]
    for state in range(m + 1):
        for char in range(2): # 0=T, 1=H
            if state < m and char == pattern[state]:
                trans[state][char] = state + 1
            else:
                # Find longest prefix which is suffix
                j = state
                while j > 0 and (j == m or char != pattern[j]):
                    j = pi[j]
                if j < m and char == pattern[j]:
                    trans[state][char] = j + 1
                else:
                    trans[state][char] = 0
    return trans

def solve_probability(g_str, k_str, p_head):
    glen = len(g_str)
    klen = len(k_str)
    
    trans_g = build_kmp(g_str)
    trans_k = build_kmp(k_str)
    
    # States: (i, j) for i=0..glen, j=0..klen
    # We map to variable index only for transient states (i < glen, j < klen)
    # Absorbing states have known values
    
    variables = []
    var_map = {}
    idx = 0
    for i in range(glen):
        for j in range(klen):
            var_map[(i, j)] = idx
            idx += 1
            variables.append((i, j))
    
    N = len(variables)
    if N == 0:
        # Start state is absorbing? (should not happen if inputs are non-empty)
        # If g or k is length 1, start state might be absorbing
        return 0.0
    
    # Build augmented matrix [N][N+1]
    # Equation for variable x_u (state u=(i,j)): 
    # x_u - p * x_next_H - (1-p) * x_next_T = 0
    # Boundary conditions modify the RHS
    
    p_fixed = p_head
    p_inv = 1.0 - p_head
    
    mat = np.zeros((N, N + 1), dtype=np.float64)
    
    for row_idx, (i, j) in enumerate(variables):
        mat[row_idx][row_idx] = 1.0
        
        # Next state on H (char 1)
        next_i_H = trans_g[i][1]
        next_j_H = trans_k[j][1]
        
        val_H = 0.0
        if next_i_H == glen and next_j_H < klen:
            val_H = 1.0 # Gon wins
        elif next_i_H < glen and next_j_H == klen:
            val_H = 0.0 # Killua wins
        elif next_i_H == glen and next_j_H == klen:
            val_H = 0.0 # Draw
        elif next_i_H == glen and glen == klen and next_j_H == klen: # Exact match overlap
            val_H = 0.0
        else:
            # Transient
            var_idx_H = var_map.get((next_i_H, next_j_H))
            if var_idx_H is not None:
                mat[row_idx][var_idx_H] -= p_fixed
            # If None (should not happen), it's absorbing, handled above
        
        # Next state on T (char 0)
        next_i_T = trans_g[i][0]
        next_j_T = trans_k[j][0]
        
        val_T = 0.0
        if next_i_T == glen and next_j_T < klen:
            val_T = 1.0
        elif next_i_T < glen and next_j_T == klen:
            val_T = 0.0
        elif next_i_T == glen and next_j_T == klen:
            val_T = 0.0
        else:
            var_idx_T = var_map.get((next_i_T, next_j_T))
            if var_idx_T is not None:
                mat[row_idx][var_idx_T] -= p_inv
                
        mat[row_idx][N] = val_H * p_fixed + val_T * p_inv
    
    # Gaussian elimination
    for i in range(N):
        pivot = mat[i][i]
        if abs(pivot) < 1e-12:
            continue
        mat[i] /= pivot
        
        for j in range(N):
            if i != j:
                factor = mat[j][i]
                mat[j] -= factor * mat[i]
                
    # Return probability of start state (0,0)
    start_idx = var_map.get((0,0))
    if start_idx is None:
        return 0.0
    
    return mat[start_idx][N]

@cocotb.test()
async def test_probability_calculator(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.g_mask.value = 0
    dut.k_mask.value = 0
    dut.g_len.value = 0
    dut.k_len.value = 0
    dut.p_fixed.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test cases
    test_cases = [
        {"g": "H", "k": "T", "p": 0.5},
        {"g": "HH", "k": "TH", "p": 0.5},
        {"g": "HTH", "k": "THT", "p": 0.7},
        {"g": "HHH", "k": "TTT", "p": 0.6}
    ]
    
    for tc in test_cases:
        g_str = tc["g"]
        k_str = tc["k"]
        p_val = tc["p"]
        
        # Prepare inputs
        # Mask: bit 0 is first char? Let's say MSB is first char or LSB. 
        # Let's use LSB as first char for simplicity in masking.
        g_mask = 0
        for i, c in enumerate(g_str):
            if c == 'H':
                g_mask |= (1 << i)
        
        k_mask = 0
        for i, c in enumerate(k_str):
            if c == 'H':
                k_mask |= (1 << i)
                
        dut.g_mask.value = g_mask
        dut.k_mask.value = k_mask
        dut.g_len.value = len(g_str)
        dut.k_len.value = len(k_str)
        dut.p_fixed.value = int(p_val * 65536)
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 1000000:
                dut._log.error("Timeout waiting for done signal")
                assert False
        
        # Read result
        hw_result_q = int(dut.result.value)
        hw_result = hw_result_q / 65536.0
        
        # Compute expected
        expected = solve_probability(g_str, k_str, p_val)
        
        # Check
        error = abs(hw_result - expected)
        dut._log.info(f"Test {g_str} vs {k_str} p={p_val}: HW={hw_result:.6f}, Exp={expected:.6f}, Err={error:.8f}")
        assert error < 1e-4, f"Result mismatch: {hw_result} vs {expected}"
        
    dut._log.info("All tests passed")
