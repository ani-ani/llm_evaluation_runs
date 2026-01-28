import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cumulative_sum(dut):
    """Test cumulative sum of nested tuple list."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (tuples, expected_result, description)
    # Each tuple: (elements, valid_length)
    test_cases = [
        ([(1, 3, 0), 2], [(5, 6, 7), 3], [(2, 6, 0), 2], 30, "Test 1: 1+3+5+6+7+2+6=30"),
        ([(2, 4, 0), 2], [(6, 7, 8), 3], [(3, 7, 0), 2], 37, "Test 2: 2+4+6+7+8+3+7=37"),
        ([(3, 5, 0), 2], [(7, 8, 9), 3], [(4, 8, 0), 2], 44, "Test 3: 3+5+7+8+9+4+8=44"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (t0, t1, t2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Unpack tuples and lengths
            tuple0, len0 = t0
            tuple1, len1 = t1
            tuple2, len2 = t2
            
            # Write tuple 0 elements
            dut.tuple_0_0.value = tuple0[0]
            dut.tuple_0_1.value = tuple0[1]
            dut.tuple_0_2.value = tuple0[2]
            
            # Write tuple 1 elements
            dut.tuple_1_0.value = tuple1[0]
            dut.tuple_1_1.value = tuple1[1]
            dut.tuple_1_2.value = tuple1[2]
            
            # Write tuple 2 elements
            dut.tuple_2_0.value = tuple2[0]
            dut.tuple_2_1.value = tuple2[1]
            dut.tuple_2_2.value = tuple2[2]
            
            # Write lengths
            dut.len_0.value = len0
            dut.len_1.value = len1
            dut.len_2.value = len2
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read and verify result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")