import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_median_three_numbers(dut):
    """Test median of three 8-bit numbers."""
    
    cocotb.log.info("Testing median_three_numbers module")
    
    # Test cases: (a, b, c, expected_median, description)
    test_cases = [
        (25, 55, 65, 55, "Test 1: median is b (55)"),
        (20, 10, 30, 20, "Test 2: median is a (20)"),
        (15, 45, 75, 45, "Test 3: median is b (45)"),
        (100, 50, 25, 50, "Descending: median is b (50)"),
        (10, 20, 10, 10, "Two equal, lower median"),
        (50, 50, 50, 50, "All equal"),
        (5, 100, 50, 50, "Scrambled: median is c (50)"),
        (0, 128, 255, 128, "Min, mid, max"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Inputs: a={a}, b={b}, c={c}")
        
        try:
            # Clamp values to 8-bit unsigned range
            a_val = clamp_to_width(a, DATA_WIDTH)
            b_val = clamp_to_width(b, DATA_WIDTH)
            c_val = clamp_to_width(c, DATA_WIDTH)
            
            # Write inputs
            dut.a.value = a_val
            dut.b.value = b_val
            dut.c.value = c_val
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.median.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.median.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: median = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
