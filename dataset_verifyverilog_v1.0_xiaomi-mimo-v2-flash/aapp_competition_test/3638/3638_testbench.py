import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Fixed-point constants
FRAC_BITS = 16
INT_BITS = 16
TOTAL_BITS = 32
ONE = 1 << FRAC_BITS  # 65536
ONE_THIRD = 21845     # 0.33333 * 65536 ≈ 21845

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def encode_seq(s):
    # Map 'R'=0, 'P'=1, 'S'=2
    mapping = {'R': 0, 'P': 1, 'S': 2}
    return [mapping.get(c, 0) for c in s]

def fixed_mul(a, b):
    return (a * b) >> FRAC_BITS

def calc_prob_exact(n, L):
    # Python reference calculation in fixed point
    if L > n:
        return 0
    # p_single = 1/3^L
    p_single = pow(ONE_THIRD, L) >> (FRAC_BITS * (L - 1)) # Simplified pow for small L
    # Recalculate strictly:
    p = ONE
    for _ in range(L):
        p = (p * ONE_THIRD) >> FRAC_BITS
    p_single = p
    
    # p_survival = 1 - p_single
    p_survival = ONE - p_single
    
    # P = 1 - p_survival^(n - L + 1)
    # Binary exponentiation
    exponent = n - L + 1
    result = ONE
    base = p_survival
    while exponent > 0:
        if exponent & 1:
            result = (result * base) >> FRAC_BITS
        base = (base * base) >> FRAC_BITS
        exponent >>= 1
    
    prob = ONE - result
    return prob

def python_sort_logic(predictions, n):
    # Calculate probs
    probs = []
    for i, seq in enumerate(predictions):
        L = len(seq)
        p = calc_prob_exact(n, L)
        probs.append((p, i, seq)) # (prob, original_idx, seq)
    
    # Sort by prob descending, stable
    probs.sort(key=lambda x: x[0], reverse=True)
    return [p[1] for p in probs] # Return indices

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rps_prediction(dut):
    # Setup Clock
    clk = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'seq_0'):
        for i in range(10):
            getattr(dut, f'seq_{i}').value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (3, 4, ["PP", "RR", "PS", "SS"]),
        (20, 3, ["PRSPS", "SSSSS", "PPSPP"])
    ]
    
    for n, s, seqs in test_cases:
        # Calculate expected output
        exp_indices = python_sort_logic(seqs, n)
        
        # Inputs
        dut.n.value = n
        dut.start.value = 1
        
        # Load sequences into dut
        if has_signal(dut, 'seq_0'):
            # Packed arrays or individual
            for i, seq in enumerate(seqs):
                # Encode sequence to 3-bit values
                encoded = encode_seq(seq)
                # Pack into 30-bit integer (10 chars * 3 bits)
                packed_val = 0
                for j, val in enumerate(encoded):
                    packed_val |= (val & 0x3) << (j * 3)
                # Assign to port
                # Assuming seq_0, seq_1... is an array of ports
                port = getattr(dut, f'seq_{i}')
                port.value = packed_val
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs
        outputs = []
        timeout = 0
        max_timeout = 20000
        
        while timeout < max_timeout:
            await RisingEdge(dut.clk)
            timeout += 1
            
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                idx = int(dut.result_idx.value)
                outputs.append(idx)
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if timeout >= max_timeout:
            raise TestFailure(f"Timeout for n={n}, s={s}")
            
        # Verify order
        if len(outputs) != s:
            raise TestFailure(f"Expected {s} outputs, got {len(outputs)}")
            
        # Check if matches expected indices
        # Note: The DUT outputs indices. We expect them to match the python sorted indices.
        for i in range(s):
            if outputs[i] != exp_indices[i]:
                # Allow for differing indices if values are tied? No, problem says "same order as input" for ties.
                # Our python logic respects stable sort. DUT must match.
                raise TestFailure(f"Mismatch at pos {i}: expected {exp_indices[i]}, got {outputs[i]}")
        
        cocotb.log.info(f"Test passed for n={n}, s={s}")
