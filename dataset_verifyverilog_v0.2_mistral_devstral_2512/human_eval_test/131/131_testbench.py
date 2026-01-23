import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_digits_product(dut):
    """Test digits_product module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from Python problem
    # Input: number, Expected: product of odd digits
    test_cases = [
        (5, 5),        # digits(5) == 5
        (54, 5),       # digits(54) == 5 (5 is odd, 4 is even)
        (120, 1),      # digits(120) == 1 (1 is odd, 2 and 0 are even)
        (5014, 5),     # digits(5014) == 5 (5, 1 are odd, 0, 4 even; 5*1=5)
        (98765, 315),  # digits(98765) == 315 (9,7,5 are odd; 9*7*5=315)
        (5576543, 2625), # digits(5576543) == 2625 (5,5,7,5,3 are odd; 5*5*7*5*3=2625)
        (2468, 0),     # digits(2468) == 0 (all even digits)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for number, expected in test_cases:
        # Load input
        dut.number.value = number
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (5 cycles)
        for _ in range(6):
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            print(f"Test passed: digits({number}) = {actual}")
            passed += 1
        else:
            print(f"Test failed: digits({number}) = {actual}, expected {expected}")
            raise TestFailure(f"Expected {expected}, got {actual}")
    
    # Edge case: all even digits
    dut.number.value = 2468
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(6):
        await RisingEdge(dut.clk)
    actual = int(dut.result.value)
    if actual == 0:
        print(f"Edge case passed: digits(2468) = {actual}")
        passed += 1
    else:
        raise TestFailure(f"Edge case failed: expected 0, got {actual}")
    
    print(f"
{passed}/{total+1} tests passed")
