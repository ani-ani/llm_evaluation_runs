import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_unique_sorted(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    test_cases = [
        # Original test scaled to 8 elements
        {"input": [5,3,5,2,3,3,9,0], "expected": [0,2,3,5,9], "count": 5},
        # All unique (should preserve order after sorting)
        {"input": [8,1,6,4,7,3,2,5], "expected": [1,2,3,4,5,6,7,8], "count": 8},
        # All duplicates
        {"input": [5,5,5,5,5,5,5,5], "expected": [5], "count": 1},
        # Edge case: zeros
        {"input": [0,0,0,0,0,0,0,0], "expected": [0], "count": 1}
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for test in test_cases:
        # Load inputs
        for i in range(8):
            dut.d_in[i].value = test["input"][i]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (72 cycles)
        for _ in range(72):
            await RisingEdge(dut.clk)
            
        # Check outputs
        assert dut.done.value == 1, "Done signal not asserted"
        
        # Verify unique count
        if dut.count.value != test["count"]:
            dut._log.error(f"Count {dut.count.value} != expected {test['count']} for input {test['input']}")
            continue
        
        # Verify sorted unique values
        valid = True
        for i in range(test["count"]):
            if dut.result[i].value != test["expected"][i]:
                valid = False
        
        if valid:
            passed += 1
            dut._log.info(f"PASS: {test['input']} -> {test['expected']}")
        else:
            actual = [dut.result[i].value for i in range(dut.count.value)]
            dut._log.error(f"FAIL: {test['input']} -> {actual}, expected {test['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")