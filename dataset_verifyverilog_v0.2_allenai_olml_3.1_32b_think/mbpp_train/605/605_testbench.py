import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def is_prime_py(n):
    """Python reference implementation"""
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    for i in range(3, int(n**0.5) + 1, 2):
        if n % i == 0:
            return False
    return True

@cocotb.test()
async def test_prime_checker(dut):
    """Test prime checker module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_in.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (13, True, "Test 1: prime 13"),
        (7, True, "Test 2: prime 7"),
        (-1010, False, "Test 3: negative -1010"),
        (1, False, "Edge: 1"),
        (2, True, "Edge: 2"),
        (4, False, "Edge: 4"),
        (17, True, "Test: 17"),
        (15, False, "Test: 15"),
        (0, False, "Edge: 0"),
        (1000000007, True, "Large prime"),  # 1000000007 is prime
    ]
    
    passed = 0
    total = len(test_cases)
    
    for num, expected, desc in test_cases:
        # Load input
        dut.num_in.value = num
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 300
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        result = bool(dut.is_prime.value)
        if result == expected:
            print(f"PASS: {desc} - num={num}, result={result}")
            passed += 1
        else:
            print(f"FAIL: {desc} - num={num}, expected={expected}, got={result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
