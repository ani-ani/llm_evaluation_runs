import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000000  # Large due to exhaustive search

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

def pack_values(values, element_bits=2):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lamp_assigner(dut):
    """Test lamp assignment solver with scaled examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (k, lamp_rows, lamp_cols, expected_result, description)
    # Coordinates are 0-indexed (1x1 in problem -> 0,0)
    test_cases = [
        # Example 1: Should return 1
        (
            5,  # k
            [0, 0, 2, 2, 1],  # lamp_rows (1,1)->(0,0), (1,3)->(0,2), (3,1)->(2,0), (3,3)->(2,2), (2,2)->(1,1)
            [0, 2, 0, 2, 1],  # lamp_cols
            1,
            "Example 1: 5 lamps in 4x4 grid"
        ),
        # Example 2: Should return 0
        (
            6,  # k
            [0, 0, 0, 2, 2, 2],  # lamp_rows
            [0, 1, 2, 0, 1, 2],  # lamp_cols
            0,
            "Example 2: 6 lamps in 4x4 grid"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, rows, cols, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  k={k}, rows={rows}, cols={cols}")
        
        try:
            # Pack the lamp coordinates
            packed_rows = pack_values(rows, 2)
            packed_cols = pack_values(cols, 2)
            
            # Set inputs
            dut.k.value = k
            dut.packed_lamp_rows.value = packed_rows
            dut.packed_lamp_cols.value = packed_cols
            dut.result.value = 0
            dut.done.value = 0
            
            # Wait for next clock edge
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")