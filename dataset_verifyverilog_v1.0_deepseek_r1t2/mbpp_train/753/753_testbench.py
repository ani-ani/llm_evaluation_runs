import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
K_WIDTH = 2
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# ENCODING/DECODING HELPERS
# ============================================================================

def encode_name(name_str):
    """Encode name string as 8-bit ASCII (first char only for simplicity)."""
    if len(name_str) > 0:
        return ord(name_str[0])
    return 0

def decode_name(encoded):
    """Decode 8-bit ASCII back to character."""
    return chr(encoded) if encoded != 0 else ''

def verify_records(records, expected, K):
    """Verify that records match expected (sorted by score, top K)."""
    # Sort Python list by score
    sorted_python = sorted(records, key=lambda x: x[1])[:K]
    # Compare
    if len(sorted_python) != len(expected):
        return False
    for i, (py_rec, exp_rec) in enumerate(zip(sorted_python, expected)):
        if py_rec[0] != exp_rec[0] or py_rec[1] != exp_rec[1]:
            return False
    return True

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_k_records(dut):
    """Test minimum K records selection from tuple list."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_tuples, K, expected_output)
    test_cases = [
        ([("Manjeet", 10), ("Akshat", 4), ("Akash", 2), ("Nikhil", 8)], 2,
         [("Akash", 2), ("Akshat", 4)]),
        ([("Sanjeev", 11), ("Angat", 5), ("Akash", 3), ("Nepin", 9)], 3,
         [("Akash", 3), ("Angat", 5), ("Nepin", 9)]),
        ([("tanmay", 14), ("Amer", 11), ("Ayesha", 9), ("SKD", 16)], 1,
         [("Ayesha", 9)]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_tuples, K, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: K={K}, Input={input_tuples}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Encode inputs
            names = [encode_name(t[0]) for t in input_tuples]
            scores = [t[1] for t in input_tuples]
            
            # Write to DUT
            dut.name_0.value = clamp_to_width(names[0], DATA_WIDTH)
            dut.name_1.value = clamp_to_width(names[1], DATA_WIDTH)
            dut.name_2.value = clamp_to_width(names[2], DATA_WIDTH)
            dut.name_3.value = clamp_to_width(names[3], DATA_WIDTH)
            
            dut.score_0.value = clamp_to_width(scores[0], DATA_WIDTH)
            dut.score_1.value = clamp_to_width(scores[1], DATA_WIDTH)
            dut.score_2.value = clamp_to_width(scores[2], DATA_WIDTH)
            dut.score_3.value = clamp_to_width(scores[3], DATA_WIDTH)
            
            dut.k.value = clamp_to_width(K, K_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read outputs
            # Read first record
            out_name_0 = int(dut.out_name_0.value)
            out_score_0 = int(dut.out_score_0.value)
            out_name_1 = int(dut.out_name_1.value)
            out_score_1 = int(dut.out_score_1.value)
            out_name_2 = int(dut.out_name_2.value)
            out_score_2 = int(dut.out_score_2.value)
            
            # Construct result list
            result = []
            # Always first record
            if is_value_defined(dut.out_name_0.value) and is_value_defined(dut.out_score_0.value):
                result.append((decode_name(out_name_0), out_score_0))
            
            # Second record if K >= 2
            if K >= 2:
                if is_value_defined(dut.out_name_1.value) and is_value_defined(dut.out_score_1.value):
                    result.append((decode_name(out_name_1), out_score_1))
            
            # Third record if K >= 3
            if K >= 3:
                if is_value_defined(dut.out_name_2.value) and is_value_defined(dut.out_score_2.value):
                    result.append((decode_name(out_name_2), out_score_2))
            
            cocotb.log.info(f"  Result: {result}")
            
            # Verify
            if len(result) != len(expected):
                raise TestFailure(f"Expected {len(expected)} records, got {len(result)}")
            
            for j, (res_rec, exp_rec) in enumerate(zip(result, expected)):
                if res_rec[0] != exp_rec[0] or res_rec[1] != exp_rec[1]:
                    raise TestFailure(f"Record {j}: expected {exp_rec}, got {res_rec}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
