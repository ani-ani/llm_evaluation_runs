import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 1
CLK_PERIOD_NS = 10
MAX_CYCLES = 20  # Allow 16 iterations + some margin

# Helper functions
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

async def start_check(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Test function
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_perfect_square(dut):
    """Test perfect square detection"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_n, expected_result, description)
    test_cases = [
        (10, 0, "10 is not a perfect square"),
        (36, 1, "36 is 6^2"),
        (14, 0, "14 is not a perfect square"),
        (196, 1, "196 is 14^2"),
        (125, 0, "125 is not a perfect square"),
        (125, 0, "125^2=15625 exceeds 8-bit, so 125 not checked"),
        (0, 1, "0 is 0^2"),
        (1, 1, "1 is 1^2"),
        (4, 1, "4 is 2^2"),
        (255, 0, "255 is not a perfect square"),
        (144, 1, "144 is 12^2"),
        (250, 0, "250 is not a perfect square"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, description) in enumerate(test_cases):
        # Skip cases that exceed 8-bit range
        if n > 255:
            cocotb.log.info(f"Test {i+1}: SKIPPED - {description}")
            continue
            
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input
            dut.n.value = n
            dut.result.value = 0  # Initialize
            
            # Start computation
            await start_check(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")