import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_multiply_unit_digits(dut):
    """Test multiply_unit_digits module with various inputs"""
    
    # Test cases: (a, b, expected_result)
    test_cases = [
        (148, 412, 16),   # 8*2=16
        (19, 28, 72),     # 9*8=72
        (2020, 1851, 0),  # 0*1=0
        (14, -15, 20),    # 4*5=20 (abs values)
        (76, 67, 42),     # 6*7=42
        (17, 27, 49),     # 7*7=49
        (0, 1, 0),        # 0*1=0
        (0, 0, 0),        # 0*0=0
        (-14, -15, 20),   # 4*5=20 (both negative)
        (123, 456, 18),   # 3*6=18
        (99, 99, 81),     # 9*9=81 (max case)
        (100, 200, 0),    # 0*0=0
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (a, b, expected) in enumerate(test_cases):
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual = int(dut.result.value)
        
        # Check result
        if actual == expected:
            dut._log.info(f"Test {i+1}: PASS - a={a}, b={b}, result={actual}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: FAIL - a={a}, b={b}, expected={expected}, got={actual}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
