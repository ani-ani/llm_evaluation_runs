import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_min_jumps(dut):
    """Test min_jumps module with various test cases"""
    
    # Helper function to convert float to Q16.16 fixed-point
    def float_to_q16_16(value):
        return int(value * 65536)
    
    # Helper function to perform integer division ceiling
    def ceil_div(a, b):
        return (a + b - 1) // b
    
    test_cases = [
        # (step_a, step_b, target_d, expected_result)
        # Test 1: steps=(3,4), d=11 -> expected 3.5
        (3, 4, 11, float_to_q16_16(3.5)),
        # Test 2: steps=(3,4), d=0 -> expected 0
        (3, 4, 0, 0),
        # Test 3: steps=(11,14), d=11 -> expected 1
        (11, 14, 11, float_to_q16_16(1)),
        # Additional test 4: steps=(5,7), d=25 -> expected 5 (25/5 = 5)
        (5, 7, 25, float_to_q16_16(5)),
        # Additional test 5: steps=(10,20), d=35 -> expected 2 (since d=35 < max_step=20? No, 35>=20, so ceil(35/20)=2)
        (10, 20, 35, float_to_q16_16(2)),
        # Additional test 6: steps=(2,3), d=3 -> expected 2 (d != min_step and d != 0)
        (2, 3, 3, float_to_q16_16(2)),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (step_a, step_b, target_d, expected) in enumerate(test_cases, 1):
        # Set inputs
        dut.step_a.value = step_a
        dut.step_b.value = step_b
        dut.target_d.value = target_d
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.jumps.value)
        
        # Verify
        if result == expected:
            passed += 1
            print(f"Test {i}: PASS - steps=({step_a},{step_b}), d={target_d}, result=0x{result:08X} (expected 0x{expected:08X})")
        else:
            print(f"Test {i}: FAIL - steps=({step_a},{step_b}), d={target_d}, got 0x{result:08X}, expected 0x{expected:08X}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"