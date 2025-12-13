import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_modulo_product(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    test_cases = [
        {"arr": [100, 10, 5, 25, 35, 14], "n": 11, "expected": 9},
        {"arr": [1, 1, 1], "n": 1, "expected": 0},
        {"arr": [1, 2, 1], "n": 2, "expected": 0},
        {"arr": [255], "n": 255, "expected": 0},  # Edge case
        {"arr": [8, 7, 6], "n": 5, "expected": 1} # 8*7*6=336 → 336%5=1
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        dut.n.value = case["n"]
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed data elements
        for val in case["arr"]:
            await RisingEdge(dut.clk)
            dut.data.value = val
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            dut.data_valid.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == case["expected"]:
            dut._log.info(f"PASS: {case['arr']} mod {case['n']} = {dut.result.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {case['arr']} mod {case['n']} = {dut.result.value}, expected {case['expected']}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total