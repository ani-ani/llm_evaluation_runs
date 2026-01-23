import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Helper function to calculate gcd
def gcd(a, b):
    while b != 0:
        a, b = b, a % b
    return a

# Helper function to solve the problem in Python
def solve_martian_tax(n, k, denominations):
    # Calculate gcd of all denominations and k
    g = 0
    for x in denominations:
        g = gcd(g, x)
    g = gcd(g, k)
    
    # Generate valid digits
    valid_digits = set()
    for m in range(k):  # Iterate enough to cover all multiples
        d = (m * g) % k
        valid_digits.add(d)
    
    return sorted(list(valid_digits))

@cocotb.test()
async def test_martian_tax_solver(dut):
    """Test the Martian Tax Solver module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.a.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases (Scaled inputs)
    test_cases = [
        {"n": 2, "k": 8, "denominations": [12, 20], "expected": [0, 4]},
        {"n": 3, "k": 10, "denominations": [10, 20, 30], "expected": [0]},
        {"n": 5, "k": 10, "denominations": [20, 16, 4, 16, 2], "expected": [0, 2, 4, 6, 8]},
        {"n": 1, "k": 10, "denominations": [1], "expected": list(range(10))},
        {"n": 2, "k": 6, "denominations": [2, 3], "expected": list(range(6))},
        {"n": 1, "k": 5, "denominations": [4], "expected": [0, 1, 2, 3, 4]},
        {"n": 2, "k": 50, "denominations": [3, 15], "expected": [0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48]}
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    print(f"
Starting tests for {total_tests} cases...")
    
    for i, tc in enumerate(test_cases):
        n = tc["n"]
        k = tc["k"]
        denoms = tc["denominations"]
        expected = tc["expected"]
        
        # Pack denominations into 'a' input
        # Assuming 'a' is a wide bus where each denomination takes 6 bits
        packed_a = 0
        for j, val in enumerate(denoms):
            packed_a |= (val & 0x3F) << (6 * j)
        
        dut.n.value = n
        dut.k.value = k
        dut.a.value = packed_a
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        found_digits = []
        timeout = 200 # Safety timeout
        
        while timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            
            if dut.valid.value == 1:
                found_digits.append(int(dut.result_d.value))
            
            if dut.done.value == 1:
                break
        
        found_digits.sort()
        
        # Verify
        print(f"Test {i+1}: n={n}, k={k}, denoms={denoms}")
        print(f"  Expected: {expected}")
        print(f"  Got:      {found_digits}")
        
        if found_digits == expected:
            passed_tests += 1
            print("  PASS")
        else:
            print("  FAIL")
    
    print(f"
Summary: {passed_tests}/{total_tests} tests passed")
    assert passed_tests == total_tests, f"Only {passed_tests} out of {total_tests} tests passed"
