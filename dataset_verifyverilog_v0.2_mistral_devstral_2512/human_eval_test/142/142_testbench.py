import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sum_squares(dut):
    """Test sum_squares module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(16):
        dut.data[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted from Python problem
    test_cases = [
        ([1, 2, 3], 6),
        ([1, 4, 9], 14),
        ([], 0),
        ([1, 1, 1, 1, 1, 1, 1, 1, 1], 9),
        ([-1, -1, -1, -1, -1, -1, -1, -1, -1], -3),
        ([0], 0),
        ([-1, -5, 2, -1, -5], -126),
        ([-56, -99, 1, 0, -2], 3030),
        ([-1, 0, 0, 0, 0, 0, 0, 0, -1], 0),
        ([-16, -9, -2, 36, 36, 26, -20, 25, -40, 20, -4, 12, -26, 35, 37], -14196),
        ([-1, -3, 17, -1, -15, 13, -1, 14, -14, -12, -5, 14, -14, 6, 13, 11], -1448),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for lst, expected in test_cases:
        # Load inputs
        dut.length.value = len(lst)
        for i in range(16):
            if i < len(lst):
                dut.data[i].value = lst[i]
            else:
                dut.data[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
        else:
            print(f"FAIL: Input={lst}, Expected={expected}, Got={actual}")
        
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
