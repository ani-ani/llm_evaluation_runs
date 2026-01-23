import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_volume_cube(dut):
    """Test volume_cube module with various side lengths"""
    
    # Test cases: (side_length, expected_volume)
    test_cases = [
        (2, 8),      # 2^3 = 8
        (3, 27),     # 3^3 = 27
        (5, 125),    # 5^3 = 125
        (0, 0),      # Edge case: 0
        (1, 1),      # Edge case: 1
        (10, 1000),  # Larger value
    ]
    
    passed = 0
    total = len(test_cases)
    
    for side, expected in test_cases:
        # Set input
        dut.side_length.value = side
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.volume.value)
        
        # Check result
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed: side_length={side}, volume={result}, expected={expected}")
        else:
            raise TestFailure(f"Test failed: side_length={side}, got volume={result}, expected={expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
