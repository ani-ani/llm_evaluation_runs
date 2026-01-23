import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16       # Fixed-point Q16.16 format
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point."""
    return int(f * 65536)

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point to float."""
    return fixed / 65536.0

async def reset_dut(dut):
    dut.rst_n.value = 0
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_trapezium_median(dut):
    """Test trapezium median calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (base1, base2, height, expected_result)
    # Test 1: 15 + 25 = 40, /2 = 20
    # Test 2: 10 + 20 = 30, /2 = 15
    # Test 3: 6 + 9 = 15, /2 = 7.5
    test_cases = [
        (15.0, 25.0, 35.0, 20.0, "Case 1: 15, 25, 35"),
        (10.0, 20.0, 30.0, 15.0, "Case 2: 10, 20, 30"),
        (6.0, 9.0, 4.0, 7.5, "Case 3: 6, 9, 4"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (b1, b2, h, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Convert to fixed-point
            b1_fp = float_to_fixed(b1)
            b2_fp = float_to_fixed(b2)
            h_fp = float_to_fixed(h)
            expected_fp = float_to_fixed(expected)
            
            cocotb.log.info(f"  Inputs (float): base1={b1}, base2={b2}, height={h}")
            cocotb.log.info(f"  Inputs (fixed): base1={b1_fp}, base2={b2_fp}, height={h_fp}")
            cocotb.log.info(f"  Expected (float): {expected}")
            cocotb.log.info(f"  Expected (fixed): {expected_fp}")
            
            # Set inputs
            dut.base1.value = b1_fp
            dut.base2.value = b2_fp
            dut.height.value = h_fp
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.median.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fp = int(dut.median.value)
            result_float = fixed_to_float(result_fp)
            
            cocotb.log.info(f"  Result (fixed): {result_fp}")
            cocotb.log.info(f"  Result (float): {result_float}")
            
            # Allow small tolerance for floating-point rounding
            if abs(result_float - expected) > 0.001:
                raise TestFailure(f"Expected {expected}, got {result_float}")
            
            cocotb.log.info(f"  Status: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Status: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")