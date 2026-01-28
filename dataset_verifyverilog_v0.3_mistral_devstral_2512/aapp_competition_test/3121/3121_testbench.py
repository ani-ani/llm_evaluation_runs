import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
NODE_WIDTH = 4
EDGE_COUNT = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_edges(dut, edges, m):
    """Write edge data to DUT. edges is list of (from, to, a, h)."""
    for i in range(EDGE_COUNT):
        if i < m:
            from_node, to_node, a, h = edges[i]
            # Clamp values to 16-bit
            from_node = clamp_to_width(from_node, 4)
            to_node = clamp_to_width(to_node, 4)
            a = clamp_to_width(a, 16)
            h = clamp_to_width(h, 16)
        else:
            from_node, to_node, a, h = 0, 0, 0, 0
        
        # Set from_i, to_i
        if has_signal(dut, f'from_{i}'):
            getattr(dut, f'from_{i}').value = from_node
        if has_signal(dut, f'to_{i}'):
            getattr(dut, f'to_{i}').value = to_node
        # Set a_i, h_i
        if has_signal(dut, f'a_{i}'):
            getattr(dut, f'a_{i}').value = a
        if has_signal(dut, f'h_{i}'):
            getattr(dut, f'h_{i}').value = h

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cave_system(dut):
    """Test the CaveSystem module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (A, H, n, m, edges, expected_output)
    # edges: list of (from, to, a, h)
    # expected_output: either "Oh no" or integer health
    test_cases = [
        (
            1, 2, 3, 2,
            [(1, 2, 1, 2), (2, 3, 1, 2)],
            "Oh no"
        ),
        (
            1, 3, 3, 2,
            [(1, 2, 1, 2), (2, 3, 1, 2)],
            1
        ),
        (
            5, 20, 5, 6,
            [(1, 2, 10, 6), (1, 3, 2, 15), (1, 4, 1, 33), (2, 5, 1, 7), (3, 4, 1000, 5), (4, 2, 5, 9)],
            10
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, H, n, m, edges, expected) in enumerate(test_cases):
        dut._log.info(f"\nRunning Test Case {i+1}: A={A}, H={H}, n={n}, m={m}")
        
        # Set inputs
        dut.A.value = A
        dut.H.value = H
        dut.n.value = n
        dut.m.value = m
        
        # Write edges
        await write_edges(dut, edges, m)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result is undefined (X/Z)")
            failed += 1
            continue
            
        result_val = int(dut.result.value)
        
        # Check
        if expected == "Oh no":
            if result_val == 0xFFFFFFFF:
                dut._log.info(f"Test {i+1}: PASS (Oh no)")
                passed += 1
            else:
                dut._log.error(f"Test {i+1}: FAIL - Expected Oh no, got {result_val}")
                failed += 1
        else:
            if result_val == expected:
                dut._log.info(f"Test {i+1}: PASS - Health = {result_val}")
                passed += 1
            else:
                dut._log.error(f"Test {i+1}: FAIL - Expected {expected}, got {result_val}")
                failed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")