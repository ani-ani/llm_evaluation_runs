import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sum_range_list(dut):
    """Test sum_range_list module"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    for i in range(12):
        dut.list1[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([2,1,5,6,8,3,4,9,10,11,8,12], 8, 10, 29),
        ([2,1,5,6,8,3,4,9,10,11,8,12], 5, 7, 16),
        ([2,1,5,6,8,3,4,9,10,11,8,12], 7, 10, 38),
        ([0,0,0,0,0,0,0,0,0,0,0,0], 0, 11, 0),  # Edge: all zeros
        ([255,255,255,255,255,255,255,255,255,255,255,255], 0, 3, 1020),  # Edge: max values
        ([1,2,3,4,5,6,7,8,9,10,11,12], 0, 0, 1),  # Edge: single element
    ]
    
    passed = 0
    total = len(test_cases)
    
    for list_data, m_val, n_val, expected in test_cases:
        # Load array
        for i, val in enumerate(list_data):
            dut.list1[i].value = val
        
        # Set parameters
        dut.m.value = m_val
        dut.n.value = n_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: sum({m_val},{n_val}) = {actual}")
        else:
            dut._log.error(f"FAIL: sum({m_val},{n_val}) = {actual}, expected {expected}")
        
        # Reset for next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
