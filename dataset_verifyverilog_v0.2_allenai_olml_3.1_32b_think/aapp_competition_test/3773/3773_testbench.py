import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_grundy_pile_solver(dut):
    """Test the Grundy pile solver with multiple test cases"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A_i.value = 0
    dut.K_i.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (A, K, Expected Grundy)
    test_cases = [
        (5, 2, 1),      # 5//2=2, 5%2=1 -> iterative -> returns 1
        (3, 3, 1),      # 3%3==0 -> returns 3//3=1
        (10, 2, 0),     # Known pattern
        (7, 3, 2),      # Complex case
        (1, 2, 0),      # A < K
        (100, 10, 10),  # A % K == 0
        (15, 4, 0),     # Moderate complexity
        (1000000000, 1000, 1000000) # Large number test
    ]
    
    passed = 0
    total = len(test_cases)
    
    for A, K, expected in test_cases:
        dut.A_i.value = A
        dut.K_i.value = K
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 200:
            print(f"Timeout for A={A}, K={K}")
            continue
            
        result = int(dut.grundy_out.value)
        
        print(f"A={A}, K={K}: Got {result}, Expected {expected}")
        
        if result == expected:
            passed += 1
        else:
            print(f"  FAILED")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
