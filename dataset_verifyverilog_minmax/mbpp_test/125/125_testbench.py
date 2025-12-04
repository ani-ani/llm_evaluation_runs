import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_diff(dut):
    # Test cases (original adapted + edge cases)
    test_cases = [
        # Original examples scaled to <=16 bits
        {"data": 0b1100001000100000, "len": 11, "expected": 6},  # "11000010001"
        {"data": 0b1011100000000000, "len": 5, "expected": 1},   # "10111"
        {"data": 0b1101110110010100, "len": 14, "expected": 2}, # "11011101100101"
        
        # Added edge cases
        {"data": 0b0000000000000000, "len": 16, "expected": 16}, # All 0s
        {"data": 0b1111111111111111, "len": 16, "expected": 0}   # All 1s
    ]
    
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.data.value = case["data"]
        dut.str_len.value = case["len"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing cycles
        await ClockCycles(dut.clk, case["len"])
        
        # Check output
        if not dut.done.value:
            await RisingEdge(dut.done)
        
        result = int(dut.max_diff.value)
        if result == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: {hex(case['data'])} len={case['len']} => {result}")
        else:
            dut._log.error(f"FAIL: {hex(case['data'])} len={case['len']} got {result}, expected {case['expected']}")
        
        await ClockCycles(dut.clk, 2)  # Inter-test gap
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
