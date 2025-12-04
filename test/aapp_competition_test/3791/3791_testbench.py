import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

@cocotb.test()
async def test_perm_shift(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Input format: (n, p_arr, expected_dev, expected_shift)
        (3, [1,2,3], 0, 0),
        (3, [2,3,1], 0, 1),
        (3, [3,2,1], 2, 1),
        (2, [1,2], 0, 0),
        (2, [2,1], 0, 1),
        # Add more 4-element test cases
        (4, [1,2,3,4], 0, 0),
        (4, [4,1,2,3], 2, 3)
    ]
    dut._log.info("Test started")
    passed = 0
    total = len(test_cases)
    
    for (n, p_list, exp_dev, exp_shift) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.n.value = 0
        for i in range(16):
            dut.p[i].value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Load test case
        pad_p = p_list + [0]*(16 - len(p_list))  # Pad to 16 elements
        for i in range(16):
            dut.p[i].value = pad_p[i] - 1  # Convert to 0-based in hardware
        dut.n.value = n
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        error = False
        if dut.min_dev.value != exp_dev:
            dut._log.error(f"Deviation mismatch: got {dut.min_dev.value}, expected {exp_dev}")
            error = True
        if dut.shift_id.value != exp_shift:
            dut._log.error(f"Shift mismatch: got {dut.shift_id.value}, expected {exp_shift}")
            error = True
        if not error:
            passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"