import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_even(dut):
    """Test the sum_even module with various inputs"""
    
    # Test cases: (input_n, expected_result, description)
    test_cases = [
        (4, 0, "4: too small (minimum is 8)"),
        (6, 0, "6: too small (minimum is 8)"),
        (8, 1, "8: valid (2+2+2+2)"),
        (10, 1, "10: valid (2+2+2+4)"),
        (11, 0, "11: odd number"),
        (12, 1, "12: valid (2+2+2+6)"),
        (13, 0, "13: odd number"),
        (16, 1, "16: valid (2+2+4+8)"),
        (0, 0, "0: too small"),
        (7, 0, "7: odd and too small"),
        (9, 0, "9: odd"),
        (100, 1, "100: large even number >= 8"),
        (255, 0, "255: maximum odd"),
        (254, 1, "254: large even >= 8"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected, description in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        
        result = int(dut.result.value)
        
        if result == expected:
            print(f"✓ PASS: {description}")
            passed += 1
        else:
            print(f"✗ FAIL: {description}")
            print(f"  Input n={n}, Expected={expected}, Got={result}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
