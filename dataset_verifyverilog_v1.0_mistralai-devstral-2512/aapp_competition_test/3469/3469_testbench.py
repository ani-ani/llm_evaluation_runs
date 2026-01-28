import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, width=8):
    # H=0, T=1, pack into bits LSB first
    val = 0
    for i, c in enumerate(s[:width]):
        bit = 1 if c == 'T' else 0
        val |= (bit << i)
    return val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Function to compute expected probability in Python for verification
def compute_expected(g, k, p):
    # Scale to 0-1000 for p, but here just use float
    len_g, len_k = len(g), len(k)
    max_len = 8  # Scaled to 8 in hardware
    g_small = g[:max_len]
    k_small = k[:max_len]
    
    # Build all possible states: suffix (0-7) + prefix match for g/k (7 bits each? But for 8 char, we track progress 0-8)
    # For simplicity, assume state encodes last 8 chars (2^8=256) + status (0: none, 1: g, 2: k, 3: both, but both is draw)
    # Actually, state = last 8 chars (as integer 0-255) + last_match_status (g, k, none) but overlaps
    # Better: state = suffix length (0-8) + last matched prefix length for g and k (0-8 each)
    # Total states: 9*9*9 = 729, but we limit to 256 for 8-bit state index.
    # Let's map last 8 chars (256) + if g/k matched (but not finished) in the suffix.
    # For hardware, we use 256 states representing last 8 chars, and track if g/k is present in the suffix (up to len)
    # But probability of full pattern requires checking if pattern appears in the sequence.
    # Given complexity, the paper solution uses linear equations for expected probability.
    # We'll simulate for small n: run 1000 flips, but for verification, use exact method.
    # For exact: States are (suf, g_pos, k_pos) where g_pos in 0..len_g (len_g<=20), but cap at 8.
    # Let's assume len_g, len_k <= 8, states 9*9*9=729, but we limit to 256 in hardware by truncating states.
    # In testbench, we'll test with len<=4, so state space 5*5*5=125, encode in 7 bits.
    # Expected prob = sum_{path} prob * Gon_win
    # Use DP over n steps, but infinite is absorption prob.
    # Solve linear system: E[s] = sum_{next} P[next] * E[next], absorbing states have fixed E.
    # Absorbing: if g only -> 1, k only -> 0, both -> 0.
    # States: all possible (g_matched, k_matched) and last few chars to detect overlaps.
    # For verification, compute via solving 125x125 matrix (small).
    pass

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gon_win_probability(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("H", "T", 0.5, 0.5),
        ("HH", "TH", 0.5, 0.25),
        ("H", "H", 0.5, 0.0),  # Identical
        ("HT", "TH", 0.5, 0.25)  # Symmetric
    ]
    
    for i, (g_str, k_str, p_float, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: g={g_str}, k={k_str}, p={p_float}")
        
        # Scale to hardware input
        g_encoded = pack_string(g_str, width=8)
        k_encoded = pack_string(k_str, width=8)
        P_int = int(round(p_float * 1000))  # 0-1000
        
        # Write inputs
        dut.g_arr.value = g_encoded
        dut.k_arr.value = k_encoded
        dut.P.value = P_int
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 10000
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout on test {i+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined on test {i+1}")
        
        result_raw = int(dut.result.value)
        # Decode Q8.8
        result = result_raw / 256.0
        
        # Compare with expected (allow small error)
        error = abs(result - expected)
        if error > 1e-3:  # Loose for fixed-point approximation
            raise TestFailure(f"Test {i+1}: Expected {expected:.6f}, got {result:.6f}, error {error:.6f}")
        
        cocotb.log.info(f"PASS: Result {result:.6f}")
