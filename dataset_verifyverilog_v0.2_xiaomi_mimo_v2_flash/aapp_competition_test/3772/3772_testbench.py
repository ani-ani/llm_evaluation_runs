import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Function to calculate expected result in Python (to compare against)
def calculate_resistance(a, b):
    res = 0
    while b != 0:
        res += a // b
        a, b = b, a % b
    return res

@cocotb.test()
async def test_resistance_calculator(dut):
    """Test the resistance calculator module"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        (1, 1),
        (3, 2),
        (199, 200),
        (1, 100),
        (21, 8),
        (5, 2),
        (13, 21),
        (74, 99),
        (2, 5),
        (4, 5),
        (1, 20),
        (100, 99),
        (15, 11),
        (5, 8),
        (2377, 1055)
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Running {total} test cases...")
    
    for a, b in test_cases:
        # Expected result
        expected = calculate_resistance(a, b)
        
        # Start the computation
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (with timeout)
        max_cycles = 128
        cycles = 0
        while not dut.done.value and cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= max_cycles:
            print(f"FAIL: a={a}, b={b} - Timeout")
            continue
            
        # Read result
        result = int(dut.result.value)
        
        if result == expected:
            print(f"PASS: a={a}, b={b} -> result={result}")
            passed += 1
        else:
            print(f"FAIL: a={a}, b={b} - Expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed: {passed}/{total}"
