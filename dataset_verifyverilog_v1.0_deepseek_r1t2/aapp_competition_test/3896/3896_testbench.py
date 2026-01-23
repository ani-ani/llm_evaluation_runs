import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
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

async def write_x_value(dut, x_str):
    """Convert binary string to 100-bit value and write to DUT."""
    if x_str == '':
        x_val = 0
    else:
        x_val = int(x_str, 2)
    dut.x_value.value = x_val
    return x_val

async def write_n(dut, n):
    """Write length n to DUT."""
    dut.n.value = n

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dance_complexity(dut):
    """Test the DanceComplexity module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (x_str, expected_output)
    test_cases = [
        ("11", 6),
        ("01", 2),
        ("1", 1),
        ("10", 4),  # Additional test: 10 -> x=2, n=2, ans=2*2^(1)=4
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: x='{x_str}', expected={expected}")
        
        try:
            # Write inputs
            n = len(x_str)
            await write_x_value(dut, x_str)
            await write_n(dut, n)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=200)  # Should complete in ~132 cycles
            
            # Read result
            if not is_value_defined(dut.ans.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.ans.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
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