import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_star_number(dut):
    # Test the star_number module
    
    # Helper function to convert integer to Q16.16 format
    def to_q16_16(value):
        return value << 16
    
    # Helper function to convert Q16.16 to integer
    def from_q16_16(value):
        return value >> 16
    
    # Test cases: (n, expected_star_number)
    test_cases = [
        (3, 37),
        (4, 73),
        (5, 121),
        (1, 1),
        (2, 13),
        (0, 1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input in Q16.16 format
        dut.n.value = to_q16_16(n)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result_raw = int(dut.result.value)
        result_int = from_q16_16(result_raw)
        
        print(f"n={n}, result=0x{result_raw:08X} ({result_int}), expected={expected}")
        
        if result_int == expected:
            passed += 1
        else:
            print(f"FAILED: n={n}, got {result_int}, expected {expected}")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"