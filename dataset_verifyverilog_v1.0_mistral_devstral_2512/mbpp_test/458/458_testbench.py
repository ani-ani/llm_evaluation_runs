import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rectangle_area(dut):
    """Test rectangle area calculation."""
    
    # Detect module interface
    has_length = hasattr(dut, 'length')
    has_breadth = hasattr(dut, 'breadth')
    has_area = hasattr(dut, 'area')
    
    if not (has_length and has_breadth and has_area):
        raise TestFailure("Module missing required signals: length, breadth, area")
    
    # Define test cases: (length, breadth, expected_area, description)
    test_cases = [
        (10, 20, 200, "Test 1: 10*20=200"),
        (10, 5, 50, "Test 2: 10*5=50"),
        (4, 2, 8, "Test 3: 4*2=8"),
        (255, 255, 65025, "Edge case: max values"),
        (0, 100, 0, "Edge case: zero length"),
        (100, 0, 0, "Edge case: zero breadth"),
        (1, 1, 1, "Edge case: minimum values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (length, breadth, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            dut.length.value = length
            dut.breadth.value = breadth
            
            # Combinational logic - wait for propagation
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.area.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.area.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: area = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")