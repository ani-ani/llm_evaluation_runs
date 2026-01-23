import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_multiples_counter(dut):
    """Test the multiples_counter module with scaled inputs"""
    
    # Create a 10MHz clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.X.value = 0
    dut.A.value = 0
    dut.B.value = 0
    dut.allowed.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: X=2, A=1, B=20, Allowed=0123456789
    # Expected: 10 (2,4,6,8,10,12,14,16,18,20)
    dut.X.value = 2
    dut.A.value = 1
    dut.B.value = 20
    dut.allowed.value = 0b1111111111  # All digits 0-9 allowed
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 1000 cycles for this small range)
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Test 1 timed out")
        
    result = int(dut.result.value)
    print(f"Test 1: X=2, A=1, B=20, Allowed=All. Result: {result}. Expected: 10")
    if result != 10:
        raise TestFailure(f"Test 1 Failed: Expected 10, got {result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: X=6, A=100, B=9294, Allowed=23689
    # Expected: 111
    # Note: Scaled down B if needed, but 9294 fits in 14 bits
    dut.X.value = 6
    dut.A.value = 100
    dut.B.value = 9294
    dut.allowed.value = 0b0000001000 | 0b0000010000 | 0b0000100000 | 0b0010000000 | 0b1000000000 # Digits 2,3,6,8,9
    # Bit 2: 4, Bit 3: 8, Bit 6: 64, Bit 8: 256, Bit 9: 512. Sum = 4+8+64+256+512 = 844
    dut.allowed.value = 844
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 15000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if timeout >= 15000:
        raise TestFailure("Test 2 timed out")
        
    result = int(dut.result.value)
    print(f"Test 2: X=6, A=100, B=9294, Allowed=23689. Result: {result}. Expected: 111")
    if result != 111:
        raise TestFailure(f"Test 2 Failed: Expected 111, got {result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: X=5, A=4395, B=5000 (Scaled down from 9999999999), Allowed=12346789
    # Expected: 0 (Based on original problem logic, or minimal)
    # Let's pick a range where we know the answer: X=3, A=1, B=15, Allowed=13579
    # Valid: 3 (allowed), 9 (allowed). 
    dut.X.value = 3
    dut.A.value = 1
    dut.B.value = 15
    dut.allowed.value = 0b1010101010 # Odd digits: 1,3,5,7,9
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if timeout >= 2000:
        raise TestFailure("Test 3 timed out")
        
    result = int(dut.result.value)
    # Multiples of 3: 3, 6, 9, 12, 15. 
    # Allowed: 3, 9. (12 has 2 which is not allowed). 
    # 15 has 5 and 1, both allowed. 
    # Wait, 15 is 5. 5 is allowed. 1 is allowed. So 15 is valid. 
    # Valid numbers: 3, 9, 15. Total 3.
    expected_test3 = 3
    print(f"Test 3: X=3, A=1, B=15, Allowed=13579. Result: {result}. Expected: {expected_test3}")
    if result != expected_test3:
        raise TestFailure(f"Test 3 Failed: Expected {expected_test3}, got {result}")
        
    print("All tests passed!")