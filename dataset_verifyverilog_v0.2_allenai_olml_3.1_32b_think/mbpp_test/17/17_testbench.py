import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_square_perimeter(dut):
    """Test square perimeter calculation with various inputs"""
    
    # Test cases with Q16.16 fixed-point representation
    # Format: (input_side_length, expected_perimeter)
    test_cases = [
        (10.0, 40.0),  # Test 1: 10 -> 40
        (5.0, 20.0),   # Test 2: 5 -> 20
        (4.0, 16.0),   # Test 3: 4 -> 16
    ]
    
    passed = 0
    total = len(test_cases)
    
    for side, expected in test_cases:
        # Convert to Q16.16 format (multiply by 2^16 = 65536)
        side_fixed = int(side * 65536)
        expected_fixed = int(expected * 65536)
        
        # Apply input
        dut.a.value = side_fixed
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = dut.perimeter.value.integer
        
        # Verify result
        if result == expected_fixed:
            print(f"PASS: side={side} (0x{side_fixed:08X}) -> perimeter={expected} (0x{expected_fixed:08X}), got 0x{result:08X}")
            passed += 1
        else:
            print(f"FAIL: side={side} (0x{side_fixed:08X}) expected 0x{expected_fixed:08X}, got 0x{result:08X}")
            raise TestFailure(f"Perimeter mismatch for side {side}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
