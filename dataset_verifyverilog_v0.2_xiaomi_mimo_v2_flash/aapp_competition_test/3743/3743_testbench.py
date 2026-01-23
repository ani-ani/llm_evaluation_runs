import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def is_prime(n):
    if n <= 1: return False
    if n <= 3: return True
    if n % 2 == 0 or n % 3 == 0: return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True

def smallest_prime_factor(n):
    if n == 1: return 1
    if n % 2 == 0:
        if (n & (n - 1)) == 0: return 2
        return 1
    i = 3
    while i * i <= n:
        if n % i == 0:
            temp = n
            while temp % i == 0:
                temp //= i
            if temp == 1:
                return i
            else:
                return 1
        i += 2
    return n

@cocotb.test()
async def test_aesthetic_path_solver(dut):
    """Test the aesthetic path solver module"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        21, 22, 23, 24, 25, 27, 30, 32, 49, 64,
        81, 100, 121, 125, 128, 243, 256, 343, 512, 729,
        1024, 2048, 3125, 4096, 6561, 8192, 15625, 16384, 32768, 59049,
        65536, 100000, 131072, 262144, 524288, 590490, 1048576, 2097152, 3486784401, 1073741824
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"Starting tests with {total} cases...")
    
    for n_val in test_cases:
        # Skip if n_val exceeds 32-bit limit or is too large for reasonable simulation
        # In this simulation, we cap at 2^32-1 for the 32-bit input
        if n_val > 0xFFFFFFFF:
            continue
            
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        max_cycles = 5000  # Timeout for large numbers
        while not dut.done.value and cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= max_cycles:
            print(f"Timeout on n={n_val}")
            continue
            
        # Read result
        actual = int(dut.result.value)
        expected = smallest_prime_factor(n_val)
        
        if actual == expected:
            passed += 1
        else:
            print(f"FAIL: n={n_val}, Expected={expected}, Got={actual}")
            raise TestFailure(f"Mismatch for n={n_val}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
