import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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

# --- Constants ---
N = 8
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 2000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Python Reference Implementation (for test generation) ---
def solve_bits_game(arr, k):
    """
    Solves the Bits game for small N (linear version).
    arr: list of ints
    k: int number of sections
    """
    n = len(arr)
    # Mask iteration: try setting bits from high to low
    # Max possible OR of all elements
    max_or = 0
    for x in arr:
        max_or |= x
    
    best = 0
    # Try to set bits from MSB to LSB
    for bit in range(15, -1, -1): # 16-bit result range
        mask = best | (1 << bit)
        
        # Check feasibility of this mask
        # 1. Every element must cover the mask bits required for the sections to be valid
        # Actually, for a section to cover 'mask', the section OR must have all bits of 'mask'.
        # Elements themselves don't strictly need to cover 'mask' individually if combined.
        # But if an element is isolated in a section (size 1), it must cover 'mask'.
        # The greedy check usually works: try to form sections covering 'mask'.
        
        valid_mask = True
        segments = 0
        current_or = 0
        
        for x in arr:
            current_or |= x
            # If current segment covers all bits in 'mask'
            if (current_or & mask) == mask:
                segments += 1
                current_or = 0
        
        # If we have a remainder, it must also form a valid segment if we need exact count
        # But the problem asks for EXACTLY K sections.
        # The greedy approach gives the MAXIMUM number of sections we can form covering 'mask'.
        # We can merge adjacent sections to reduce count.
        # So we can form 'mask' if we can form >= K sections covering 'mask'.
        
        if current_or > 0:
            # Check if the last partial segment can cover mask
            if (current_or & mask) == mask:
                segments += 1
            else:
                # If the last bit doesn't cover mask, it's invalid for the greedy partition
                # unless we merge it with the previous one.
                # However, if we merge, the OR increases, potentially keeping the mask valid.
                # A simple check: can we form at least K segments covering mask?
                pass
        
        # Correction: The greedy check finds the MAXIMUM number of disjoint segments covering mask.
        # If max_segments >= K, we can merge segments to get exactly K.
        # If max_segments < K, we cannot cover mask with K sections.
        
        # Re-run greedy strictly for checking max possible segments covering mask
        segments = 0
        current_or = 0
        for x in arr:
            current_or |= x
            if (current_or & mask) == mask:
                segments += 1
                current_or = 0
        
        # Note: If there's a remainder, it means we couldn't form a full segment at the end.
        # This remainder cannot form a valid segment covering 'mask' (since we reset only when valid).
        # So we can't count it. But we can merge it into the previous segment.
        # Merging doesn't reduce the count, it keeps it or increases OR (keeping validity).
        # So 'segments' is the count of valid segments we formed greedily.
        # We can achieve any count <= segments by merging.
        
        if segments >= k:
            best = mask
            
    return best

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bits_game(dut):
    """Test the Bits Game module."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ([2, 3, 4, 1, 0, 0, 0, 0], 2, "Sample 1 (padded)"),
        ([2, 2, 2, 4, 4, 4, 0, 0], 3, "Sample 2 (padded)"),
        ([0, 1, 2, 3, 0, 0, 0, 0], 1, "Sample 3 (padded)"),
        ([15, 15, 15, 15, 0, 0, 0, 0], 4, "All same"),
        ([1, 2, 4, 8, 16, 32, 64, 128], 2, "Distinct powers of 2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, k_val, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Calculate expected result using Python reference
        expected = solve_bits_game(arr_vals, k_val)
        cocotb.log.info(f"Expected result: {expected}")
        
        try:
            # Write inputs
            # Array A: 8 elements, 8 bits each
            for idx in range(N):
                dut.A[idx].value = clamp_to_width(arr_vals[idx], DATA_WIDTH)
            
            dut.K.value = k_val
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=1000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
