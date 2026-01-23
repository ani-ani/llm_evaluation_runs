import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 1
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

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

async def pack_array(values, element_bits=8):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        clamped_val = clamp_to_width(val, element_bits)
        result |= clamped_val << (i * element_bits)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_ball_checker(dut):
    """Test ball_checker module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, sizes_list, expected_result)
    # Expected: "YES" means result=1, "NO" means result=0
    test_cases = [
        (4, [18,55,16,17], "YES"),
        (6, [40,41,43,44,44,44], "NO"),
        (8, [5,972,3,4,1,4,970,971], "YES"),
        (3, [959,747,656], "NO"),
        (4, [1,2,2,3], "YES"),
        (3, [3,1,2], "YES"),
        (3, [500,999,1000], "NO"),
        (3, [1000,999,998], "YES"),
        (3, [1,2,7], "NO"),
        (5, [1,100,2,100,3], "YES"),
        (3, [1,1,1], "NO"),
        (4, [998,999,1000,1000], "YES"),
        (6, [1,1,2,2,3,3], "YES"),
        (3, [13,13,13], "NO"),
        (3, [42,42,42], "NO"),
        (4, [4,3,4,5], "YES"),
        (3, [2,3,2], "YES"),
        (5, [2,3,3,3,4], "YES"),
        (3, [1,2,2], "YES"),
        (4, [1,2,4,4], "NO"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, sizes, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, sizes={sizes}, expected={expected}")
        
        try:
            # Pad sizes to 8 elements with 0
            padded_sizes = sizes + [0] * (8 - len(sizes))
            
            # Pack array
            sizes_flat = await pack_array(padded_sizes)
            
            # Set inputs
            dut.n.value = n
            dut.sizes_flat.value = sizes_flat
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            actual = "YES" if int(dut.result.value) == 1 else "NO"
            
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  PASS: result = {actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
