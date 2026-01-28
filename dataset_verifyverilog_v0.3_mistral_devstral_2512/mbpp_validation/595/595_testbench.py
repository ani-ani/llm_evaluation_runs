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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_swaps(dut):
    """Test minimum swaps calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (str1, str2, expected_result, expected_possible, description)
    # Binary strings converted to 8-bit integers
    test_cases = [
        # Test 1: "1101" (13), "1110" (14) - 1 mismatch position, odd, NOT POSSIBLE
        # But wait, let me recalculate: 1101 vs 1110 -> position 1 matches, position 2 matches, 
        # position 3 differs, position 4 differs -> 2 mismatches, even -> 1 swap
        # However the example says 1 swap, but my logic says 2 mismatches = 1 swap
        # Actually: 1101 vs 1110 -> index 0:1=1, index1:1=1, index2:0!=1, index3:1!=0
        # So mismatches at index 2 and 3 = 2 mismatches = 1 swap. The result is 1.
        (0b1101, 0b1110, 1, 1, "Test 1: 1101 vs 1110"),
        
        # Test 2: "111" (7), "000" (0) - 3 mismatches, odd, NOT POSSIBLE
        # Using 8 bits: 00000111 vs 00000000 -> mismatches at 3 positions = odd
        (0b00000111, 0b00000000, 0, 0, "Test 2: 111 vs 000"),
        
        # Test 3: "111" (7), "110" (6) - 1 mismatch, odd, NOT POSSIBLE
        # Using 8 bits: 00000111 vs 00000110 -> 1 mismatch = odd
        (0b00000111, 0b00000110, 0, 0, "Test 3: 111 vs 110"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (str1_val, str2_val, exp_result, exp_possible, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            dut.str1.value = str1_val
            dut.str2.value = str2_val
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.result.value) or not is_value_defined(dut.possible.value):
                raise TestFailure("Result or possible signal is undefined (X/Z)")
            
            result = int(dut.result.value)
            possible = int(dut.possible.value)
            
            # Verify
            if result != exp_result or possible != exp_possible:
                raise TestFailure(f"Expected result={exp_result}, possible={exp_possible}, got result={result}, possible={possible}")
            
            cocotb.log.info(f"  PASS: result={result}, possible={possible}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")