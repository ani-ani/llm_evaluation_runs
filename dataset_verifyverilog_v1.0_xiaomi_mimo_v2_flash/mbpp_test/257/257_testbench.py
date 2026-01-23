import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return 0
    return min(max_val, value)

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'a'):
        dut.a.value = 0
    if has_signal(dut, 'b'):
        dut.b.value = 0
    
    for _ in range(cycles):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_swap_numbers(dut):
    """Test the swap_numbers module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_a, input_b, expected_first, expected_second, description)
    test_cases = [
        (10, 20, 20, 10, "swap(10, 20) -> (20, 10)"),
        (15, 17, 17, 15, "swap(15, 17) -> (17, 15)"),
        (100, 200, 200, 100, "swap(100, 200) -> (200, 100)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_a, input_b, expected_first, expected_second, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp inputs to DATA_WIDTH
            val_a = clamp_to_width(input_a, DATA_WIDTH)
            val_b = clamp_to_width(input_b, DATA_WIDTH)
            
            # Write inputs
            dut.a.value = val_a
            dut.b.value = val_b
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.out_first.value) or not is_value_defined(dut.out_second.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            result_first = int(dut.out_first.value)
            result_second = int(dut.out_second.value)
            
            # Verify
            if result_first != expected_first:
                raise TestFailure(f"out_first: expected {expected_first}, got {result_first}")
            if result_second != expected_second:
                raise TestFailure(f"out_second: expected {expected_second}, got {result_second}")
            
            cocotb.log.info(f"  PASS: out_first={result_first}, out_second={result_second}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")