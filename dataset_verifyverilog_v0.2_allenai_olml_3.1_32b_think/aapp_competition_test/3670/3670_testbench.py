import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def get_divisors(n):
    divisors = []
    for i in range(2, n + 1):
        if n % i == 0:
            divisors.append(i)
    return divisors

def solve(numbers):
    """Find all M > 1 where all numbers give same remainder modulo M"""
    if len(numbers) < 2:
        return []
    
    # Calculate all pairwise absolute differences
    diffs = []
    for i in range(len(numbers)):
        for j in range(i + 1, len(numbers)):
            diffs.append(abs(numbers[i] - numbers[j]))
    
    # Find GCD of all differences
    if not diffs:
        return []
    
    common_gcd = diffs[0]
    for d in diffs[1:]:
        common_gcd = gcd(common_gcd, d)
    
    # Get divisors > 1
    return get_divisors(common_gcd)

@cocotb.test()
async def test_luka_border_solver(dut):
    """Test Luka's Border Solver"""
    
    # Test cases: (numbers, expected_Ms)
    test_cases = [
        ([6, 34, 38], [2, 4]),
        ([5, 17, 23, 14, 83], [3]),
        ([10, 20, 30, 40], [10, 5, 2]),  # Added to use 4 numbers
        ([7, 15, 23, 31], [8, 4, 2]),    # Added to use 4 numbers
        ([100, 50, 25], [25, 5]),        # Extended to 4 numbers
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (numbers, expected) in enumerate(test_cases):
        # Scale numbers to fit 8-bit range (1-100)
        # Original problem: 1 to 1,000,000,000
        # We'll scale down: divide by 10^7 and map to 1-100
        scaled_numbers = []
        for n in numbers:
            # Scale: original range 1-1000000000 maps to 1-100
            scaled = int((n / 10000000.0) * 100) + 1
            if scaled < 1:
                scaled = 1
            if scaled > 100:
                scaled = 100
            scaled_numbers.append(scaled)
        
        # For 4 numbers, we need exactly 4 inputs
        while len(scaled_numbers) < 4:
            # Add dummy numbers that maintain the same mod pattern
            # If all numbers have same remainder mod M, adding 0 works (0 mod M = 0)
            # But our numbers are 1-100, so we need to be careful
            # Let's add the first number shifted to maintain pattern
            # Actually, let's add 0 if allowed, or duplicate first number + M
            # For simplicity in this test, we'll add a number that preserves divisibility
            scaled_numbers.append(scaled_numbers[0])
        
        # Truncate to 4
        scaled_numbers = scaled_numbers[:4]
        
        print(f"Test {i+1}: Original={numbers}, Scaled={scaled_numbers}")
        
        # Set inputs
        dut.num0.value = scaled_numbers[0]
        dut.num1.value = scaled_numbers[1]
        dut.num2.value = scaled_numbers[2]
        dut.num3.value = scaled_numbers[3]
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        outputs = []
        for j in range(8):
            output_val = getattr(dut, f'm{j}').value
            if output_val != 0:
                outputs.append(int(output_val))
        
        outputs.sort()
        expected.sort()
        
        # For verification, we need to recalculate expected for scaled numbers
        actual_expected = solve(scaled_numbers)
        
        print(f"  Expected divisors: {actual_expected}")
        print(f"  Got outputs: {outputs}")
        
        if outputs == actual_expected:
            passed += 1
            print(f"  PASS")
        else:
            print(f"  FAIL")
            raise TestFailure(f"Test {i+1} failed: expected {actual_expected}, got {outputs}")
    
    print(f"
{passed}/{total} tests passed")
    
    # Verify all outputs
    assert passed == total, f"Only {passed} out of {total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    # Edge case 1: Consecutive numbers (differences = 1, only M=1, but M>1 so no answer?)
    # Actually, if differences are 1, gcd=1, divisors>1 = []
    # But problem guarantees at least one M exists
    # Let's use [10, 20, 30, 40] -> differences 10, 20, 10 -> gcd=10 -> divisors 2,5,10
    
    dut.num0.value = 10
    dut.num1.value = 20
    dut.num2.value = 30
    dut.num3.value = 40
    
    await Timer(10, units='ns')
    
    outputs = []
    for j in range(8):
        val = getattr(dut, f'm{j}').value
        if val != 0:
            outputs.append(int(val))
    
    outputs.sort()
    # Expected: divisors of gcd(10,20,10,10,20,10) = divisors of 10 = [2,5,10]
    expected = [2, 5, 10]
    
    if outputs == expected:
        print(f"Edge case test: PASS - got {outputs}")
    else:
        raise TestFailure(f"Edge case failed: expected {expected}, got {outputs}")
