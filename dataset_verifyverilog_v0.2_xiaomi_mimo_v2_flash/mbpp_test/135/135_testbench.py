import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_hexagonal_number(dut):
    """Test hexagonal number calculation for various inputs"""
    
    # Test cases: (input n, expected result)
    test_cases = [
        (1, 1),      # 1 * (2*1 - 1) = 1 * 1 = 1
        (5, 45),     # 5 * (2*5 - 1) = 5 * 9 = 45
        (7, 91),     # 7 * (2*7 - 1) = 7 * 13 = 91
        (10, 190),   # 10 * (2*10 - 1) = 10 * 19 = 190
        (0, 0),      # Edge case: n=0
        (100, 19900) # 100 * (2*100 - 1) = 100 * 199 = 19900
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases for hexagonal_number module")
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"PASS: n={n}, result={result}, expected={expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n}, got result={result}, expected={expected}")
            raise TestFailure(f"Mismatch for n={n}: got {result}, expected {expected}")
    
    dut._log.info(f"
=== Test Summary: {passed}/{total} tests passed ===")
