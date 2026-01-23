import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_perfect_square_check(dut):
    """Test perfect square checker for 8-bit numbers"""
    
    # Test cases: (number, expected_result, description)
    test_cases = [
        (0, 1, "0 is 0^2"),
        (1, 1, "1 is 1^2"),
        (4, 1, "4 is 2^2"),
        (9, 1, "9 is 3^2"),
        (16, 1, "16 is 4^2"),
        (25, 1, "25 is 5^2"),
        (36, 1, "36 is 6^2"),
        (49, 1, "49 is 7^2"),
        (64, 1, "64 is 8^2"),
        (81, 1, "81 is 9^2"),
        (100, 1, "100 is 10^2"),
        (121, 1, "121 is 11^2"),
        (144, 1, "144 is 12^2"),
        (169, 1, "169 is 13^2"),
        (196, 1, "196 is 14^2"),
        (225, 1, "225 is 15^2"),
        (2, 0, "2 is not a perfect square"),
        (3, 0, "3 is not a perfect square"),
        (5, 0, "5 is not a perfect square"),
        (10, 0, "10 is not a perfect square"),
        (14, 0, "14 is not a perfect square"),
        (15, 0, "15 is not a perfect square"),
        (17, 0, "17 is not a perfect square"),
        (125, 0, "125 is not a perfect square"),
        (255, 0, "255 is not a perfect square"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for number, expected, description in test_cases:
        # Set input
        dut.number.value = number
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.is_perfect_square.value)
        
        # Check result
        if result == expected:
            passed += 1
            print(f"✓ PASS: number={number} ({description}) -> result={result}")
        else:
            print(f"✗ FAIL: number={number} ({description}) -> expected={expected}, got={result}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
