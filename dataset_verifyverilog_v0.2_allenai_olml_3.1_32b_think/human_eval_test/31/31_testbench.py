import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def is_prime_py(n):
    """Python reference for is_prime"""
    if n <= 1:
        return False
    if n <= 3:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True

@cocotb.test()
async def test_is_prime(dut):
    """Test is_prime module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for 16-bit range
    test_cases = [
        (6, False),
        (101, True),
        (11, True),
        (13441, True),
        (61, True),
        (4, False),
        (1, False),
        (5, True),
        (17, True),
        (5 * 17, False),
        (11 * 7, False),
        (2, True),
        (3, True),
        (9, False),
        (15, False),
        (1009, True),
        (65535, False),  # 3*5*17*257
        (65521, True),   # prime
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 300
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TimeoutError(f"Test timed out for n={n_val}")
        
        # Check result
        result = bool(dut.is_prime_result.value)
        if result == expected:
            passed += 1
            print(f"✓ n={n_val}: expected {expected}, got {result}")
        else:
            print(f"✗ n={n_val}: expected {expected}, got {result}")
        
        # Wait for next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"