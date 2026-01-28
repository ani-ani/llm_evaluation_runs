import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 3          # For a, b (0..4)
SCORE_WIDTH = 8         # Score range -16..16 fits in 8-bit signed
ARR_WIDTH = 8           # Arrangement vector width (max 8 cards)
LEN_WIDTH = 4           # Length of arrangement (a+b, 0..8)
CLK_PERIOD_NS = 10
MAX_CYCLES = 20         # Max cycles for computation

# Helper functions

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Python reference implementation for verification
def compute_optimal(a, b):
    """Returns (score, arrangement_string) for optimal arrangement."""
    if a == 0:
        return -b*b, 'x'*b
    if b == 0:
        return a*a, 'o'*a
    
    best_score = -float('inf')
    best_p = None
    best_q = None
    best_r = None
    
    # Try p from 1 to a
    for p in range(1, a+1):
        # Sum of squares for 'o' blocks
        large_o = a - p + 1
        sum_o_sq = large_o*large_o + (p-1)*1
        
        gaps = p + 1
        q = b // gaps
        r = b % gaps
        
        # Sum of squares for 'x' blocks (minimized)
        sum_x_sq = r*(q+1)*(q+1) + (gaps - r)*q*q
        
        score = sum_o_sq - sum_x_sq
        
        if score > best_score:
            best_score = score
            best_p = p
            best_q = q
            best_r = r
    
    # Construct arrangement
    large_o = a - best_p + 1
    small_o = 1
    gaps = best_p + 1
    
    arr_list = []
    # First gap
    first_gap = best_q + 1 if best_r > 0 else best_q
    arr_list.extend(['x'] * first_gap)
    # Large 'o' block
    arr_list.extend(['o'] * large_o)
    
    # Remaining gaps and small 'o' blocks
    for i in range(1, best_p):
        gap_size = best_q + 1 if i < best_r else best_q
        arr_list.extend(['x'] * gap_size)
        arr_list.extend(['o'] * small_o)
    
    # Last gap
    last_gap = best_q  # last gap never gets extra because we already used r gaps
    arr_list.extend(['x'] * last_gap)
    
    arrangement = ''.join(arr_list)
    return best_score, arrangement

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_card_optimizer(dut):
    """Test CardArrangementOptimizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b, expected_score, expected_arrangement)
    test_cases = [
        (0, 1, -1, "x"),
        (1, 0, 1, "o"),
        (1, 1, 0, "xo"),
        (2, 0, 4, "oo"),
        (0, 2, -4, "xx"),
        (2, 1, 3, "xoo"),
        (1, 2, -4, "xxox"),
        (2, 2, 2, "xoox"),
        (3, 0, 9, "ooo"),
        (0, 3, -9, "xxx"),
        (3, 1, 8, "xooo"),
        (1, 3, -4, "xxox"),
        (4, 0, 16, "oooo"),
        (0, 4, -16, "xxxx"),
        (4, 1, 15, "xoooo"),
        (1, 4, -9, "xxxxo"),
        (3, 2, 7, "xoooxx"),
        (2, 3, -2, "xxooxx"),
        (4, 2, 14, "xoooox"),
        (2, 4, -6, "xxxooxx"),
        (3, 3, 3, "xoooxxx"),
        (4, 3, 11, "xoooxx"),
        (3, 4, -1, "xxxooxx"),
        (4, 4, 8, "xoooxxx"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_val, b_val, exp_score, exp_arr) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_val}, b={b_val}")
        
        # Compute reference
        ref_score, ref_arr = compute_optimal(a_val, b_val)
        # Use reference as ground truth
        exp_score = ref_score
        exp_arr = ref_arr
        
        # Drive inputs
        dut.a.value = a_val
        dut.b.value = b_val
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        done = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"  FAIL: Timeout waiting for done")
            failed += 1
            continue
        
        # Read outputs
        if not is_value_defined(dut.score.value):
            cocotb.log.error(f"  FAIL: Score is undefined")
            failed += 1
            continue
        
        score_raw = int(dut.score.value)
        score = to_signed(score_raw, SCORE_WIDTH)
        length = int(dut.length.value) if is_value_defined(dut.length.value) else 0
        
        # Read arrangement
        arr_bits = []
        for j in range(ARR_WIDTH):
            if j < length:
                bit = getattr(dut.arrangement, f'arrangement_{j}', None)
                if bit is None:
                    bit = dut.arrangement[j]
                if is_value_defined(bit.value):
                    arr_bits.append(str(int(bit.value)))
                else:
                    arr_bits.append('X')
            else:
                arr_bits.append('0')
        
        arr_str = ''.join(arr_bits[:length]).replace('1', 'o').replace('0', 'x')
        
        # Verify
        errors = []
        if score != exp_score:
            errors.append(f"score: expected {exp_score}, got {score}")
        if length != len(exp_arr):
            errors.append(f"length: expected {len(exp_arr)}, got {length}")
        if arr_str != exp_arr:
            errors.append(f"arrangement: expected '{exp_arr}', got '{arr_str}'")
        
        if errors:
            cocotb.log.error(f"  FAIL: {'; '.join(errors)}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: score={score}, arr='{arr_str}'")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")