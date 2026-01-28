import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Enough for 37 divisions * 64 cycles per division

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gerald_coins(dut):
    """Test the gerald_coins module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (1, 1),      # Example 1
        (4, 2),      # Example 2
        (3, 1),      # 3%3==0 -> n=1 -> 1//3+1=1
        (9, 1),      # 9%3==0 -> n=1 -> 1//3+1=1
        (10, 4),     # 10%3!=0 -> 10//3+1=4
        (27, 1),     # 27%3==0 -> n=9 -> n%3==0 -> n=3 -> n%3==0 -> n=1 -> 1//3+1=1
        (2, 1),      # 2%3!=0 -> 2//3+1=1
        (8, 3),      # 8%3!=0 -> 8//3+1=3
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, expected={expected}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.start.value = 1
            
            # Wait one cycle for start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
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
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")