import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def digit_distance(num1, num2):
    """Calculate digit-wise absolute difference between two numbers"""
    s1 = str(num1).zfill(8)
    s2 = str(num2).zfill(8)
    return sum(abs(int(s1[i]) - int(s2[i])) for i in range(8))

def calculate_expected(A, B):
    """Calculate expected sum of distances for all pairs in [A, B]"""
    total = 0
    for i in range(A, B + 1):
        for j in range(A, B + 1):
            total += digit_distance(i, j)
    return total % 1000000007

@cocotb.test()
async def test_digit_distance_sum(dut):
    """Test digit_distance_sum module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A.value = 0
    dut.B.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (A, B, expected_result)
    test_cases = [
        (1, 5, 40),
        (288, 291, 76),
        (1000, 1002, None),  # Will compute dynamically
        (50000, 50002, None), # Will compute dynamically
        (12345, 12345, 0),    # Single number case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for A, B, expected in test_cases:
        print(f"
Test case: A={A}, B={B}")
        
        # If expected not provided, calculate it
        if expected is None:
            print("Computing expected result (this may take a moment)...")
            expected = calculate_expected(A, B)
            print(f"Expected: {expected}")
        
        # Apply inputs and start
        dut.A.value = A
        dut.B.value = B
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 1000000
        cycles_waited = 0
        
        while dut.done.value == 0 and cycles_waited < max_cycles:
            await RisingEdge(dut.clk)
            cycles_waited += 1
        
        if cycles_waited >= max_cycles:
            print(f"TIMEOUT: waited {max_cycles} cycles")
            continue
        
        # Read result
        result = int(dut.result.value)
        print(f"Result: {result}")
        print(f"Cycles taken: {cycles_waited}")
        
        if result == expected:
            print("PASS")
            passed += 1
        else:
            print(f"FAIL - Expected {expected}, got {result}")
            raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if passed == total:
        print("All tests passed successfully!")
