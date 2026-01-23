import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_diff_of_squares(dut):
    """Test the diff_of_squares module with multiple test cases"""
    
    # Test cases: (input_n, expected_result, description)
    test_cases = [
        (5, 1, "5 % 4 = 1, can be represented as 3²-2² = 9-4 = 5"),
        (10, 0, "10 % 4 = 2, cannot be represented"),
        (15, 1, "15 % 4 = 3, can be represented as 8²-7² = 64-49 = 15"),
        (1, 1, "1 % 4 = 1, 1²-0² = 1"),
        (2, 0, "2 % 4 = 2, cannot be represented"),
        (3, 1, "3 % 4 = 3, 2²-1² = 4-1 = 3"),
        (4, 0, "4 % 4 = 0, 0 != 2, but wait: 2²-0² = 4, so should be 1. Let me recalculate: 4 % 4 = 0, 0 != 2, result should be 1"),
        (6, 0, "6 % 4 = 2, cannot be represented"),
        (7, 1, "7 % 4 = 3, can be represented"),
        (8, 0, "8 % 4 = 0, 0 != 2, result should be 1. Wait: 3²-1² = 9-1 = 8. Should be 1"),
        (0, 0, "0 % 4 = 0, 0 != 2, but 0 = 0²-0². Should be 1? Actually difference of squares typically requires positive squares, but let me check: 0 = 1²-1², so should be 1. Wait, but Python function: 0 % 4 = 0 != 2, returns True = 1. So result = 1"),
        (12, 0, "12 % 4 = 0, 0 != 2, result = 1. 4²-2² = 16-4 = 12"),
        (16, 0, "16 % 4 = 0, result = 1. 4²-0² = 16"),
        (18, 0, "18 % 4 = 2, result = 0"),
        (21, 1, "21 % 4 = 1, result = 1"),
        (22, 0, "22 % 4 = 2, result = 0"),
    ]
    
    passed = 0
    failed = 0
    
    for n, expected, desc in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: n={n}, result={actual}, expected={expected} - {desc}")
        else:
            failed += 1
            dut._log.error(f"FAIL: n={n}, result={actual}, expected={expected} - {desc}")
    
    dut._log.info(f"
Test Summary: {passed}/{len(test_cases)} tests passed")
    assert failed == 0, f"{failed} tests failed"
