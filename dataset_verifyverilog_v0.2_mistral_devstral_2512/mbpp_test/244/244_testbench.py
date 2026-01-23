import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_next_perfect_square(dut):
    """Test next perfect square calculation"""
    
    # Test cases: (input_N, expected_result)
    test_cases = [
        (35, 36),
        (6, 9),
        (9, 16),
        (0, 1),
        (1, 4),
        (2, 4),
        (3, 4),
        (15, 16),
        (16, 25),
        (24, 25),
        (25, 36),
        (100, 121),
        (255, 256),
        (256, 289),
        (1023, 1024),
        (65534, 0),  # 256*256 = 65536 wraps to 0 in 16 bits
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Running {total} test cases for next_perfect_square:")
    print("-" * 60)
    
    for N, expected in test_cases:
        dut.N.value = N
        await Timer(1, units='ns')
        
        result = int(dut.result.value)
        
        # Handle 16-bit wrap-around for expected value
        expected_wrapped = expected & 0xFFFF
        
        passed_test = (result == expected_wrapped)
        status = "PASS" if passed_test else "FAIL"
        
        print(f"N={N:5d} | Expected: {expected_wrapped:5d} | Got: {result:5d} | {status}")
        
        if passed_test:
            passed += 1
        else:
            # Show the mathematical calculation for debugging
            sqrt_n = math.isqrt(N)
            next_n = sqrt_n + 1
            actual_calc = next_n * next_n
            print(f"  Math: sqrt({N})={sqrt_n}, next={next_n}, square={actual_calc}")
    
    print("-" * 60)
    print(f"SUMMARY: {passed}/{total} tests passed")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"
