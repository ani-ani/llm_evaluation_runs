import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10

# Helper functions
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Helper to set circle parameters
def set_circle(dut, index, x, y, r):
    """Set circle parameters for given index (1, 2, or 3)."""
    if index == 1:
        dut.x1.value = from_signed(x, DATA_WIDTH)
        dut.y1.value = from_signed(y, DATA_WIDTH)
        dut.r1.value = from_signed(r, DATA_WIDTH)
    elif index == 2:
        dut.x2.value = from_signed(x, DATA_WIDTH)
        dut.y2.value = from_signed(y, DATA_WIDTH)
        dut.r2.value = from_signed(r, DATA_WIDTH)
    elif index == 3:
        dut.x3.value = from_signed(x, DATA_WIDTH)
        dut.y3.value = from_signed(y, DATA_WIDTH)
        dut.r3.value = from_signed(r, DATA_WIDTH)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_regions(dut):
    """Test the regions module with various circle configurations."""
    
    # Test cases: (n, circles, expected_result)
    test_cases = [
        # n=1
        (1, [(0, 0, 10)], 2),
        (1, [(5, 5, 1)], 2),
        
        # n=2 - disjoint
        (2, [(-10, 10, 1), (10, -10, 1)], 3),
        (2, [(-10, -10, 10), (10, 10, 10)], 3),
        
        # n=2 - tangent
        (2, [(-6, 6, 9), (3, -6, 6)], 3),
        
        # n=2 - intersect
        (2, [(0, 0, 2), (3, 0, 2)], 4),
        
        # n=3 - various cases from examples
        (3, [(0, 0, 1), (2, 0, 1), (4, 0, 1)], 4),
        (3, [(0, 0, 2), (3, 0, 2), (6, 0, 2)], 6),
        (3, [(0, 0, 2), (2, 0, 2), (1, 1, 2)], 8),
        (3, [(0, 0, 2), (0, 0, 4), (3, 0, 2)], 6),
        (3, [(1, 0, 1), (-1, 0, 1), (0, 1, 1)], 5),
        (3, [(0, 0, 1), (1, 0, 1), (2, 0, 1)], 4),
        (3, [(-3, 0, 5), (3, 0, 5), (0, 0, 4)], 7),
        (3, [(0, 0, 1), (0, 1, 1), (0, 2, 1)], 4),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, circles, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, circles={circles}, expected={expected}")
        
        try:
            # Set n
            dut.n.value = n
            
            # Set circle parameters
            for idx, (x, y, r) in enumerate(circles, 1):
                set_circle(dut, idx, x, y, r)
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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