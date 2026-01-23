import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test()
async def test_iscube(dut):
    """Test iscube module with scaled 8-bit signed integer inputs."""
    
    # List of perfect cubes in 8-bit signed range (-128 to 127)
    # -64, -27, -8, -1, 0, 1, 8, 27, 64
    
    # Test cases: (input_value, expected_result)
    test_cases = [
        (0, True),       # 0^3
        (1, True),       # 1^3
        (-1, True),      # (-1)^3
        (8, True),       # 2^3
        (-8, True),      # (-2)^3
        (27, True),      # 3^3
        (-27, True),     # (-3)^3
        (64, True),      # 4^3
        (-64, True),     # (-4)^3
        (2, False),      # Not a cube
        (-2, False),     # Not a cube
        (100, False),    # Not a cube
        (-100, False),   # Not a cube
        (127, False),    # Max val, not a cube
        (-128, False),   # Min val, not a cube
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (val, expected) in enumerate(test_cases):
        # Assign input
        dut.a.value = val
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.is_cube.value):
            raise TestFailure(f"Test {i}: Output is undefined (X/Z)")
        
        # Read result
        result = bool(int(dut.is_cube.value))
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i}: PASS - Input {val}, Result {result}")
            passed += 1
        else:
            dut._log.error(f"Test {i}: FAIL - Input {val}, Expected {expected}, Got {result}")
            raise TestFailure(f"Test {i} failed")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
