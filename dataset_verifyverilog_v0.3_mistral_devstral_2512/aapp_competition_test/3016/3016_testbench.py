import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration for our scaled problem
DATA_WIDTH = 2
RESULT_WIDTH = 32
MODULO = 1000000007

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

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_ball_arrangement(dut):
    """Test scaled ball arrangement module."""
    
    # Test case 1: From problem sample 4 adapted to 2 colors
    # Original: 3 colors, counts 1,2,3; forbidden {1,2}; no pattern
    # Scaled: 2 colors, count1=1, count2=2; forbidden both; pattern_length=0
    dut.count1.value = 1
    dut.count2.value = 2
    dut.forbidden.value = 0b11  # Both colors forbidden
    dut.pattern_length.value = 0
    dut.pattern0.value = 0
    dut.pattern1.value = 0
    
    await Timer(10, units='ns')
    
    result = safe_int(dut.result.value)
    expected = 0  # All permutations have adjacent forbidden colors
    
    if result != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {result}")
    
    # Test case 2: Two colors, counts 2 and 2, no constraints, no pattern
    dut.count1.value = 2
    dut.count2.value = 2
    dut.forbidden.value = 0
    dut.pattern_length.value = 0
    
    await Timer(10, units='ns')
    
    result = safe_int(dut.result.value)
    expected = 6  # Total permutations = 4!/(2!2!)=6
    
    if result != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {result}")
    
    # Test case 3: One color, two balls
    dut.count1.value = 2
    dut.count2.value = 0
    dut.forbidden.value = 0
    dut.pattern_length.value = 0
    
    await Timer(10, units='ns')
    
    result = safe_int(dut.result.value)
    expected = 1  # Only [1,1] arrangement
    
    if result != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {result}")
    
    # Test case 4: Pattern matching
    dut.count1.value = 1
    dut.count2.value = 1
    dut.forbidden.value = 0
    dut.pattern_length.value = 2
    dut.pattern0.value = 1  # Pattern: color1 then color2
    dut.pattern1.value = 2
    
    await Timer(10, units='ns')
    
    result = safe_int(dut.result.value)
    expected = 1  # [1,2] has pattern, [2,1] does not
    
    if result != expected:
        raise TestFailure(f"Test 4 failed: expected {expected}, got {result}")
    
    # Test case 5: Adjacency constraint with counts 2 and 1
    dut.count1.value = 2
    dut.count2.value = 1
    dut.forbidden.value = 0b01  # Only color1 forbidden
    dut.pattern_length.value = 2
    dut.pattern0.value = 1
    dut.pattern1.value = 2
    
    await Timer(10, units='ns')
    
    result = safe_int(dut.result.value)
    expected = 1  # Only [1,2,1] is valid and has pattern
    
    if result != expected:
        raise TestFailure(f"Test 5 failed: expected {expected}, got {result}")
    
    dut._log.info("All tests passed!")
