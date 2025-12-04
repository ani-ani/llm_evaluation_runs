import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_crush(dut):
    # Create clock (50 MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the module
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    # Test cases - scaled for n=8
    test_cases = [
        ("4", [2, 3, 1, 4, 5, 6, 7, 8], 3),   # Original n=4 padded
        ("-1", [2, 2, 4, 2, 5, 6, 7, 8], 0xFFFF),
        ("1", [2, 1, 4, 3, 5, 6, 7, 8], 1)
    ]
    
    passed = 0
    for case_id, (expected_str, crush_list, expected_val) in enumerate(test_cases):
        # Apply inputs (convert to 0-based indices)
        for i in range(8):
            val = crush_list[i] - 1  # Crush numbers were 1-indexed
            dut.crunch_arr.value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.t.value
        if actual == expected_val:
            passed += 1
            dut._log.info(f"Test {case_id} PASSED")
        else:
            dut._log.error(f"Test {case_id} FAILED: Expected {expected_str} ({expected_val}), got {actual}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 2)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")