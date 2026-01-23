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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_multiply_adjacent(dut):
    """Test multiply_adjacent module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_tuple, expected_output_tuple)
    test_cases = [
        ((1, 5, 7, 8, 10), (5, 35, 56, 80)),
        ((2, 4, 5, 6, 7), (8, 20, 30, 42)),
        ((12, 13, 14, 9, 15), (156, 182, 126, 135)),
        ((12,), ()),  # Single element - empty output
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_tuple, expected_tuple) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Input={input_tuple}")
        
        try:
            # Set length
            length = len(input_tuple)
            dut.length.value = length
            
            # Set array elements (only valid ones)
            if length >= 1:
                dut.arr_0.value = clamp_to_width(input_tuple[0], DATA_WIDTH)
            if length >= 2:
                dut.arr_1.value = clamp_to_width(input_tuple[1], DATA_WIDTH)
            if length >= 3:
                dut.arr_2.value = clamp_to_width(input_tuple[2], DATA_WIDTH)
            if length >= 4:
                dut.arr_3.value = clamp_to_width(input_tuple[3], DATA_WIDTH)
            if length >= 5:
                dut.arr_4.value = clamp_to_width(input_tuple[4], DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Handle special case of empty output
            if length == 1:
                # Should assert done immediately
                await RisingEdge(dut.clk)
                if not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                    raise TestFailure("done not asserted for single element input")
                cocotb.log.info("  PASS: Single element handled correctly")
                passed += 1
                continue
            
            # For multi-element inputs
            results = []
            expected_iter = iter(expected_tuple)
            
            # Collect all results as they come
            while True:
                await RisingEdge(dut.clk)
                
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    result = int(dut.result.value)
                    results.append(result)
                    expected_val = next(expected_iter)
                    
                    if result != expected_val:
                        raise TestFailure(f"At position {len(results)-1}: expected {expected_val}, got {result}")
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            # Verify we got all expected results
            if len(results) != len(expected_tuple):
                raise TestFailure(f"Expected {len(expected_tuple)} results, got {len(results)}")
            
            cocotb.log.info(f"  PASS: Results {results} match expected {list(expected_tuple)}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")