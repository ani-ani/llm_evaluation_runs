import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
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

async def write_array_elements(dut, values):
    """Write array values to individual ports arr_0 through arr_7."""
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sum_range_fsm(dut):
    """Test sum_range_fsm module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array_values, m, n, expected_sum, description)
    test_cases = [
        ([2,1,5,6,8,3,4,9], 8, 10, 29, "Test 1: indices 8-10 on truncated array - 29"),
        ([2,1,5,6,8,3,4,9], 5, 7, 16, "Test 2: indices 5-7 - 3+4+9=16"),
        ([2,1,5,6,8,3,4,9], 7, 10, 38, "Test 3: indices 7-10 - 9+10+11+8=38"),
        ([1,2,3,4,5,6,7,8], 0, 7, 36, "Test 4: full array sum 1-8 = 36"),
        ([10,20,30,40,50,60,70,80], 2, 5, 180, "Test 5: middle range - 30+40+50+60=180"),
        ([5,5,5,5,5,5,5,5], 0, 3, 20, "Test 6: single value repeated - 5+5+5+5=20"),
        ([255,255,255,255,0,0,0,0], 0, 3, 1020, "Test 7: max values 255*4=1020"),
        ([1,2,3,4,5,6,7,8], 3, 3, 4, "Test 8: single element - index 3 = 4"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_values, m, n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Validate inputs fit array bounds
            if m > 7 or n > 7 or m < 0 or n < 0:
                cocotb.log.warning(f"  SKIPPED: indices {m}-{n} out of bounds 0-7")
                continue
            
            if m > n:
                cocotb.log.warning(f"  SKIPPED: m > n ({m} > {n})")
                continue
            
            # Write array values to individual ports
            await write_array_elements(dut, arr_values)
            
            # Write m and n
            dut.m.value = m
            dut.n.value = n
            
            # Wait 1 cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=50)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: sum = {result}")
            passed += 1
            
            # Wait for done to go low
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")