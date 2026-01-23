import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_binary_seq_counter(dut):
    """Test binary sequence counter with Q16.16 fixed-point format"""
    
    # Initialize inputs
    dut.n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    
    # Test cases with expected results in Q16.16 format
    test_cases = [
        (1, 2.0),   # 2.0 * 65536 = 131072
        (2, 6.0),   # 6.0 * 65536 = 393216
        (3, 20.0),  # 20.0 * 65536 = 1310720
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected_float in test_cases:
        dut.n.value = n_val
        dut.start.value = 1
        await Timer(10, units='ns')
        
        # Read result
        result_val = int(dut.result.value)
        
        # Convert back to float
        result_float = result_val / 65536.0
        
        # Calculate expected Q16.16 value
        expected_q16 = int(expected_float * 65536)
        
        # Allow small tolerance for fixed-point rounding
        tolerance = 0.01
        
        if abs(result_float - expected_float) < tolerance:
            print(f"Test n={n_val}: PASS - Got {result_float:.4f}, Expected {expected_float:.4f}")
            passed += 1
        else:
            print(f"Test n={n_val}: FAIL - Got {result_val} ({result_float:.4f}), Expected {expected_q16} ({expected_float:.4f})")
    
    dut.start.value = 0
    await Timer(10, units='ns')
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases for the binary sequence counter"""
    
    # Initialize
    dut.n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    
    edge_cases = [
        (4, 70.0),   # n=4: C(4,0)^2 + C(4,1)^2 + C(4,2)^2 + C(4,3)^2 + C(4,4)^2 = 1+16+36+16+1 = 70
        (5, 252.0),  # n=5: 1+25+100+100+25+1 = 252
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for n_val, expected_float in edge_cases:
        dut.n.value = n_val
        dut.start.value = 1
        await Timer(10, units='ns')
        
        result_val = int(dut.result.value)
        result_float = result_val / 65536.0
        
        tolerance = 0.01
        
        if abs(result_float - expected_float) < tolerance:
            print(f"Edge case n={n_val}: PASS - Got {result_float:.4f}, Expected {expected_float:.4f}")
            passed += 1
        else:
            print(f"Edge case n={n_val}: FAIL - Got {result_float:.4f}, Expected {expected_float:.4f}")
    
    dut.start.value = 0
    await Timer(10, units='ns')
    
    print(f"
Edge case Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} edge cases passed"
