import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

# Helper to compute GCD
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

@cocotb.test()
async def test_bst_solver_8(dut):
    """Test the BST solver with various inputs"""
    
    # Test case 1: Input from example 1 (scaled down)
    # Original: 3 6 9 18 36 108. Let's pick 6 elements and pad to 8 or take first 8 distinct.
    # Let's use a valid chain: 2, 4, 6, 8, 10, 12, 14, 16 (All evens -> GCD >= 2)
    dut.nums.value = [2, 4, 6, 8, 10, 12, 14, 16]
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "Test 1 Failed: Expected Yes for even numbers"
    print("Test 1 Passed: Even numbers (Valid)")

    # Test case 2: Two primes (invalid)
    # 3, 5, 7, 11, 13, 17, 19, 23
    dut.nums.value = [3, 5, 7, 11, 13, 17, 19, 23]
    await Timer(10, units='ns')
    assert dut.possible.value == 0, "Test 2 Failed: Expected No for distinct primes"
    print("Test 2 Passed: Primes (Invalid)")

    # Test case 3: Mixed valid/invalid
    # 2, 3, 4, 6, 8, 9, 12, 16
    # GCD(2,3)=1 (bad edge), GCD(2,4)=2 (good)
    # Can we build a tree?
    # 4 is root: left {2}, right {6,8,9,12,16}. 2 connects to 4. 6 connects to 4. Good.
    # Subtree {6,8,9,12,16}: root 8 connects to 4? Yes. Left {6} connects to 8? Yes. Right {9,12,16} needs root 12? 12-9 (3), 12-16 (4). Yes.
    dut.nums.value = [2, 3, 4, 6, 8, 9, 12, 16]
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "Test 3 Failed: Expected Yes"
    print("Test 3 Passed: Mixed numbers (Valid)")

    # Test case 4: Original Example 2
    # 7, 17 (scaled to fit 8 inputs, padded with rest primes)
    dut.nums.value = [7, 17, 23, 29, 31, 37, 41, 43]
    await Timer(10, units='ns')
    assert dut.possible.value == 0, "Test 4 Failed: Expected No"
    print("Test 4 Passed: Mostly primes (Invalid)")

    # Test case 5: Powers of 2 (valid)
    # 2, 4, 8, 16, 32, 64, 128, 256
    dut.nums.value = [2, 4, 8, 16, 32, 64, 128, 256]
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "Test 5 Failed: Expected Yes"
    print("Test 5 Passed: Powers of 2 (Valid)")

    # Test case 6: Original Example 3 (scaled)
    # 4 8 10 12 15 18 33 44 81 -> Take first 8
    dut.nums.value = [4, 8, 10, 12, 15, 18, 33, 44]
    await Timer(10, units='ns')
    assert dut.possible.value == 1, "Test 6 Failed: Expected Yes"
    print("Test 6 Passed: Example 3 subset (Valid)")

    print("All tests passed!")
