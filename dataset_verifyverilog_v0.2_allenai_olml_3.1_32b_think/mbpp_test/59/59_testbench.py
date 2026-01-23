import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_octagonal_number(dut):
    """Test octagonal number calculation for various inputs"""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (0, 0),      # 0th octagonal number
        (1, 1),      # 1st: 3*1 - 2*1 = 1
        (5, 65),     # Given test case
        (10, 280),   # Given test case
        (15, 645),   # Given test case
        (2, 8),      # Additional: 3*4 - 4 = 8
        (3, 21),     # Additional: 3*9 - 6 = 21
        (20, 1160),  # Larger test case
        (255, 194565) # Max 8-bit input (will overflow 16-bit output but test anyway)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(1, units='ns')
        
        result = int(dut.result.value)
        
        # Mask to 16 bits since we declared 16-bit output
        result_masked = result & 0xFFFF
        expected_masked = expected & 0xFFFF
        
        if result_masked == expected_masked:
            passed += 1
            dut._log.info(f"n={n}: result={result} (expected={expected}) - PASS")
        else:
            dut._log.error(f"n={n}: result={result} (expected={expected}) - FAIL")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
