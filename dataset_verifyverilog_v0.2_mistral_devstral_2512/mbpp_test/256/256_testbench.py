import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

def to_bin(value, bits=4):
    """Convert integer to binary string representation"""
    return f"{value:0{bits}b}"

@cocotb.test()
async def test_prime_counter(dut):
    """Test prime counting functionality for values 0-15"""
    
    # Expected primes less than each value for n in [0,15]
    # Primes in [0,15): 2, 3, 5, 7, 11, 13 (6 total)
    expected_results = {
        0: 0,   # No primes less than 0
        1: 0,   # No primes less than 1
        2: 0,   # No primes less than 2 (prime 2 is not less than 2)
        3: 1,   # 1 prime: {2}
        4: 2,   # 2 primes: {2,3}
        5: 2,   # 2 primes: {2,3}
        6: 3,   # 3 primes: {2,3,5}
        7: 4,   # 4 primes: {2,3,5,7}
        8: 4,   # 4 primes: {2,3,5,7}
        9: 4,   # 4 primes: {2,3,5,7}
        10: 4,  # 4 primes: {2,3,5,7}
        11: 5,  # 5 primes: {2,3,5,7,11}
        12: 5,  # 5 primes: {2,3,5,7,11}
        13: 6,  # 6 primes: {2,3,5,7,11,13}
        14: 6,  # 6 primes: {2,3,5,7,11,13}
        15: 6   # 6 primes: {2,3,5,7,11,13}
    }
    
    passed = 0
    total = 0
    
    # Test all values from 0 to 15
    for n in range(16):
        total += 1
        
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle (small delay)
        await Timer(10, units='ns')
        
        # Read output
        count = int(dut.count.value)
        expected = expected_results[n]
        
        # Verify
        if count == expected:
            passed += 1
            dut._log.info(f"n={n} ({to_bin(n)}): count={count} (expected {expected}) ✓")
        else:
            dut._log.error(f"n={n} ({to_bin(n)}): count={count} (expected {expected}) ✗")
            raise TestFailure(f"Test failed for n={n}")
    
    # Test specific problem cases that fit in range
    problem_cases = [(5, 2), (10, 4)]
    for n, expected in problem_cases:
        total += 1
        dut.n.value = n
        await Timer(10, units='ns')
        count = int(dut.count.value)
        if count == expected:
            passed += 1
            dut._log.info(f"Problem case n={n}: count={count} (expected {expected}) ✓")
        else:
            dut._log.error(f"Problem case n={n}: count={count} (expected {expected}) ✗")
            raise TestFailure(f"Problem case failed for n={n}")
    
    # Final summary
    dut._log.info(f"
=== TEST SUMMARY: {passed}/{total} tests passed ===")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
