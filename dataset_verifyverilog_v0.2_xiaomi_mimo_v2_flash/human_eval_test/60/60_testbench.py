import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_sum_to_n(dut):
    """Test sum_to_n module with various inputs"""
    
    # Test cases: (n, expected_sum)
    test_cases = [
        (1, 1),
        (5, 15),
        (6, 21),
        (10, 55),
        (11, 66),
        (30, 465),
        (100, 5050)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"n={n}: result={result} (expected {expected}) ✓")
        else:
            dut._log.error(f"n={n}: result={result} (expected {expected}) ✗")
    
    dut._log.info(f"{passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
