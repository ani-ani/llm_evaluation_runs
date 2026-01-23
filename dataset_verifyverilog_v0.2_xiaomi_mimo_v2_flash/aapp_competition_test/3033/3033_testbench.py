import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_min_number_finder(dut):
    """Test the min_number_finder module"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, expected_result, expected_impossible)
    # N=24 -> factors: 8,3 -> sorted: 38
    # N=11 -> impossible (prime > 7)
    # N=216 -> factors: 9,8,3 -> 389 but also 6,6,6 -> 666. 389 < 666, so answer is 389
    # N=1 -> no digits needed, but we must output something. Convention: 1
    
    test_cases = [
        (24, 38, 0),   # 38
        (11, 0, 1),    # impossible
        (216, 389, 0), # 389 (9*8*3=216)
        (1, 1, 0),     # edge case
        (6, 6, 0),     # single digit
        (72, 38, 0),   # 8*9=72, sorted 38
        (81, 99, 0),   # 9*9=81
        (27, 93, 0),   # 9*3=27
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected, exp_impossible in test_cases:
        # Set inputs
        dut.N.value = n
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check results
        result = int(dut.result.value)
        impossible = int(dut.impossible.value)
        
        if impossible != exp_impossible:
            print(f"Test N={n}: Expected impossible={exp_impossible}, got {impossible}")
            continue
        
        if not impossible:
            if result != expected:
                print(f"Test N={n}: Expected {expected}, got {result}")
                # Check if result is at least valid (product equals N)
                # For this test, we just verify against expected
                continue
        
        passed += 1
        print(f"Test N={n}: PASSED (result={result}, impossible={impossible})")
    
    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
