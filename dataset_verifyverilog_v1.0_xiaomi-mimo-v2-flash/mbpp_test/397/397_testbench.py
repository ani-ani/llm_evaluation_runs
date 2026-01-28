import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 8

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Python reference implementation
def median_numbers(a, b, c):
    if a > b:
        if a < c:
            median = a
        elif b > c:
            median = b
        else:
            median = c
    else:
        if a > c:
            median = a
        elif b < c:
            median = b
        else:
            median = c
    return median

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_median_comparator(dut):
    """Test median of three 8-bit unsigned integers"""
    
    # Combinational circuit - no clock needed
    # Set some test cases
    test_cases = [
        (25, 55, 65, 55, "Ascending"),
        (20, 10, 30, 20, "Middle is first"),
        (15, 45, 75, 45, "Middle is second"),
        (75, 15, 45, 45, "Middle is third"),
        (0, 0, 0, 0, "All zeros"),
        (255, 255, 255, 255, "All max"),
        (128, 128, 255, 128, "Two equal smaller"),
        (128, 255, 128, 128, "Two equal larger"),
        (0, 255, 127, 127, "Spread out"),
        (100, 50, 150, 100, "Middle at first"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({a}, {b}, {c}) => {expected}")
        
        # Clamp inputs to 8-bit range
        a_val = clamp_to_width(a, DATA_WIDTH)
        b_val = clamp_to_width(b, DATA_WIDTH)
        c_val = clamp_to_width(c, DATA_WIDTH)
        
        # Set inputs directly (combinational)
        dut.a.value = a_val
        dut.b.value = b_val
        dut.c.value = c_val
        
        # Wait for propagation
        await Timer(10, units='ns')
        
        # Check output
        if not is_value_defined(dut.median.value):
            cocotb.log.error(f"FAIL: Result undefined for test {i+1}")
            failed += 1
            continue
        
        result = int(dut.median.value)
        
        # Compute expected using reference implementation
        expected_median = median_numbers(a_val, b_val, c_val)
        
        # For equal values, either is acceptable
        if a_val == b_val == c_val:
            if result != expected_median:
                cocotb.log.error(f"FAIL: Test {i+1} - Expected {expected_median}, got {result}")
                failed += 1
            else:
                passed += 1
        else:
            # For unique values, exact match expected
            if result != expected_median:
                cocotb.log.error(f"FAIL: Test {i+1} - Expected {expected_median}, got {result}")
                failed += 1
            else:
                passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed")
