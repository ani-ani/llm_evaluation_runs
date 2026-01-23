import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random

@cocotb.test()
async def test_byteconn_solver(dut):
    """Test the ByteConn333ct solver with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.digit.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    # Test 1: "361" (N=3, padded to 8)
    # Digits: 3, 6, 1. Sum = 10. No subset sum divisible by 3.
    # Wait, sum is 3+6+1 = 10. No subset sum % 3 == 0? Correct. Result = 0? 
    # Wait, Sample Input 1 says 361 -> 3.
    # 361: sum = 10. 
    # Subsets divisible by 3? 
    # Subsets: {3}, {6}, {1}. 
    # {3} sum=3 (div by 3). Valid.
    # {6} sum=6 (div by 3). Valid.
    # {1} sum=1 (not div by 3).
    # {3,6} sum=9 (div by 3). Valid.
    # {3,1} sum=4.
    # {6,1} sum=7.
    # {3,6,1} sum=10.
    # So valid: {3}, {6}, {3,6}. That's 3. 
    # Wait, check Sample 2: "11" -> 0. Sum=2. No subsets div by 3. Correct.
    
    # Let's use the problem statement examples.
    
    test_vectors = [
        {"digits": ["3", "6", "1", "0", "0", "0", "0", "0"], "expected": 3},
        {"digits": ["1", "1", "0", "0", "0", "0", "0", "0"], "expected": 0},
        {"digits": ["3", "0", "5", "1", "0", "0", "0", "0"], "expected": 6},
        # Edge case: Single zero -> 1 valid (the subset {0} -> number 0)
        {"digits": ["0", "0", "0", "0", "0", "0", "0", "0"], "expected": 8}, 
    ]
    
    for i, vec in enumerate(test_vectors):
        print(f"
Running Test Case {i+1}: {''.join(vec['digits']).strip('0')}")
        
        # Prepare input array for Verilog
        # Convert characters to 8-bit ASCII values
        packed_digits = 0
        for idx, char in enumerate(vec['digits']):
            ascii_val = ord(char)
            packed_digits |= (ascii_val << (idx * 8))
        
        dut.digit.value = packed_digits
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 300:
                print("Error: Timeout waiting for done signal")
                assert False
        
        # Check result
        actual = int(dut.result.value)
        expected = vec['expected']
        
        print(f"Expected: {expected}, Got: {actual}")
        assert actual == expected, f"Test {i+1} failed! Expected {expected}, got {actual}"
        
        await RisingEdge(dut.clk)
    
    print("
All tests passed!")
