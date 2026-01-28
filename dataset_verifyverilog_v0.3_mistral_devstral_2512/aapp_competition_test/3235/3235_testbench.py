import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
N = 4                      # Number of friends (nodes)
M = 8                      # Number of IOUs (edges)
WEIGHT_WIDTH = 10          # Width for debt amounts
NODE_WIDTH = 3             # Width for node IDs
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000         # Max cycles for computation

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

def pack_flat(values, element_width, num_elements):
    """Pack list of values into a single integer (packed flat vector)."""
    result = 0
    for i, val in enumerate(values):
        result |= (clamp_to_width(val, element_width) & ((1 << element_width) - 1)) << (i * element_width)
    return result

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_iou_settlement(dut):
    """Test IOU settlement module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, a_list, b_list, c_list, expected_remaining_edges)
    # expected_remaining_edges is list of (a, b, c) tuples
    test_cases = [
        # Sample Input 1: All cycles cancel
        (
            4, 5,
            [0, 1, 0, 3, 2],
            [1, 2, 3, 2, 0],
            [10, 10, 10, 10, 20],
            []  # No remaining edges
        ),
        # Sample Input 2: Simple cancellation
        (
            2, 2,
            [0, 1],
            [1, 0],
            [20, 5],
            [(0, 1, 15)]  # Only this edge remains
        ),
        # Sample Input 3: Partial cancellation, multiple edges remain
        (
            4, 5,
            [0, 1, 0, 3, 2],
            [1, 2, 3, 2, 0],
            [10, 10, 10, 10, 10],
            [(3, 2, 10), (0, 3, 10)]  # Two edges remain
        ),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (n, m, a_list, b_list, c_list, expected) in enumerate(test_cases):
        dut._log.info(f"\nRunning Test Case {idx+1}: n={n}, m={m}")
        
        # Pack inputs into flat vectors
        a_flat = pack_flat(a_list, NODE_WIDTH, M)
        b_flat = pack_flat(b_list, NODE_WIDTH, M)
        c_flat = pack_flat(c_list, WEIGHT_WIDTH, M)
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.a_flat.value = a_flat
        dut.b_flat.value = b_flat
        dut.c_flat.value = c_flat
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
            
            # Read output graph and extract remaining IOUs
            remaining = []
            for i in range(N):
                for j in range(N):
                    if i == j:
                        continue
                    weight = safe_int(dut.graph[i][j].value)
                    if weight > 0:
                        remaining.append((i, j, weight))
            
            # Sort both lists for comparison
            remaining_sorted = sorted(remaining)
            expected_sorted = sorted(expected)
            
            if remaining_sorted == expected_sorted:
                dut._log.info(f"  PASS: {len(remaining)} IOUs remaining, as expected")
                passed += 1
            else:
                dut._log.error(f"  FAIL: Expected {expected_sorted}, got {remaining_sorted}")
                failed += 1
                
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
