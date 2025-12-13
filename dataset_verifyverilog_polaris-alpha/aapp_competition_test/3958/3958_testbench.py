import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_zebra(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ("0010100", 7, True),  # Original: valid (scaled)
        ("111", 3, False),
        ("0", 1, True),
        ("0101", 4, False)
    ]
    passed = 0
    
    for s, length, expected_valid in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input string (16-bit fixed width)
        s_bin = 0
        for i, char in enumerate(s):
            s_bin |= (int(char) << (15 - i))
        dut.s.value = s_bin
        dut.str_len.value = length
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result validity
        if dut.valid.value == expected_valid:
            passed += 1
            # TODO: Add index verification for valid cases
        else:
            dut._log.error("Test failed: %s len=%d expected_valid=%d got_valid=%d" % (s, length, expected_valid, dut.valid.value))
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
