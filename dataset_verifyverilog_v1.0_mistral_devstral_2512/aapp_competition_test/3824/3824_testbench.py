import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_minimal_path(dut):
    """Test minimal path computation"""
    
    # Test cases from the problem
    test_cases = [
        ((1, 5, 5, 2), 18),
        ((0, 1, 0, 0), 8),
        ((-100, -100, 100, 100), 804),
        ((-100, -100, -100, 100), 406),
        ((-100, -100, 100, -100), 406),
        ((100, -100, -100, -100), 406),
        ((100, -100, -100, 100), 804),
        ((100, -100, 100, 100), 406),
        ((-100, 100, -100, -100), 406),
        ((-100, 100, 100, -100), 804),
        ((-100, 100, 100, 100), 406),
        ((100, 100, -100, -100), 804),
        ((100, 100, -100, 100), 406),
        ((100, 100, 100, -100), 406),
        ((45, -43, 45, -44), 8),
        ((76, 76, 75, 75), 8),
        ((-34, -56, -35, -56), 8),
        ((56, -7, 55, -6), 8),
        ((43, -11, 43, -10), 8),
        ((1, -3, 2, -2), 8),
        ((-27, -25, -28, 68), 192),
        ((25, 76, 24, 76), 8),
        ((-53, 63, -53, 62), 8),
        ((63, 41, 62, 40), 8),
        ((0, 0, 0, 1), 8),
        ((0, 0, 1, 0), 8),
        ((0, 0, 1, 1), 8),
        ((0, 1, 0, 0), 8),
        ((0, 1, 1, 0), 8),
        ((0, 1, 1, 1), 8),
        ((1, 0, 0, 0), 8),
        ((1, 0, 0, 1), 8),
        ((1, 0, 1, 1), 8),
        ((1, 1, 0, 0), 8),
        ((1, 1, 0, 1), 8),
        ((1, 1, 1, 0), 8),
        ((100, 100, 99, -100), 406),
        ((100, 100, -100, 99), 406),
        ((-100, -100, -99, 100), 406),
        ((-100, -100, 100, -99), 406),
        ((0, 0, 0, 2), 8),
        ((0, 0, 2, 0), 8),
        ((0, 0, 2, 2), 12),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected) in enumerate(test_cases):
        x1, y1, x2, y2 = inputs
        
        # Convert signed inputs to unsigned representation for Verilog
        dut.x1.value = from_signed(x1, DATA_WIDTH)
        dut.y1.value = from_signed(y1, DATA_WIDTH)
        dut.x2.value = from_signed(x2, DATA_WIDTH)
        dut.y2.value = from_signed(y2, DATA_WIDTH)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check result is defined
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: Result is undefined (X/Z)")
            failed += 1
            continue
        
        # Read result
        result = int(dut.result.value)
        
        # Convert to signed for display if needed
        result_signed = to_signed(result, RESULT_WIDTH) if result >= (1 << (RESULT_WIDTH - 1)) else result
        
        if result == expected:
            cocotb.log.info(f"Test {i+1}: PASS - Inputs ({x1},{y1}) ({x2},{y2}), Result {result}")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1}: FAIL - Expected {expected}, got {result}")
            cocotb.log.error(f"  Inputs: ({x1},{y1}) ({x2},{y2})")
            failed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
