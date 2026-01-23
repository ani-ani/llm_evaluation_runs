import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_challenge24(dut):
    """Test Challenge 24 module with various test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (a, b, c, d, expected_grade, description)
    # Use 8'hFF (255) to indicate impossible
    test_cases = [
        (3, 5, 5, 2, 1, "Grade 1 expression exists"),
        (1, 1, 1, 1, 255, "Impossible case"),
        (3, 6, 2, 3, 0, "Perfect grade 0 expression"),
        (2, 2, 6, 1, 255, "Impossible case"),
        (8, 3, 8, 3, 0, "Multiple ways to 24"),
        (4, 6, 2, 2, 255, "Impossible case"),
        (7, 5, 5, 4, 255, "Impossible case"),
        (1, 2, 3, 4, 255, "Impossible case"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, d, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {a}, {b}, {c}, {d}")
        cocotb.log.info(f"  Expected: {'impossible' if expected == 255 else expected}")
        
        try:
            # Set inputs
            dut.a.value = a
            dut.b.value = b
            dut.c.value = c
            dut.d.value = d
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.grade.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.grade.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")