import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_max_subarray(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Original Test 1
        {"a": [10,20,-30,-1], "n":4, "k":3, "expected":30},
        # Original Test 2 (padded with 0)
        {"a": [-1,10,20,0], "n":3, "k":2, "expected":59},
        # Original Test 3
        {"a": [-1,-2,-3,0], "n":3, "k":3, "expected":-1},
        # All positive
        {"a": [5,10,15,0], "n":3, "k":2, "expected":60},
        # Max boundary
        {"a": [127,127,127,127], "n":4, "k":3, "expected":4*127*3}
    ]

    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Load inputs
        dut.start.value = 0
        dut.n.value = case["n"]
        dut.k.value = case["k"]
        dut.a0.value = int(np.int8(case["a"][0]))
        dut.a1.value = int(np.int8(case["a"][1]))
        dut.a2.value = int(np.int8(case["a"][2]))
        dut.a3.value = int(np.int8(case["a"][3]))
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        result = dut.max_sum.value.signed_integer
        try:
            assert result == case["expected"], f"Got {result}, expected {case['expected']}"
            passed += 1
            dut._log.info(f"PASS: {case}")
        except AssertionError as e:
            dut._log.error(f"FAIL: {case} | {str(e)}")
        
        # Reset state
        await RisingEdge(dut.clk)
        
    dut._log.info(f"Test summary: {passed}/{total} passed")