import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sum_subarray(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    test_cases = [
        {"arr": [1,2,3], "expected": 20, "len": 3},
        {"arr": [1,2], "expected": 5, "len": 2},
        {"arr": [1,2,3,4], "expected": 84, "len": 4},
        {"arr": [15,0], "expected": 15, "len": 2},  # Edge case: zero element
        {"arr": [1]*8, "expected": 6560, "len": 8}  # All ones (sum hypercumulation)
    ]
    
    passed = 0

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Load inputs
        for i in range(8):
            dut.element[i].value = case["arr"][i] if i < case["len"] else 0
        dut.arr_len.value = case["len"] - 1  # 0-based length
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        cycles = 0
        while (not dut.done.value) and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
            
        # Check result
        if dut.done.value != 1:
            dut._log.error(f"Test failed: Timeout waiting for done")
        elif dut.result.value.integer == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: {case['arr']} -> {dut.result.value.integer}")
        else:
            dut._log.error(f"FAIL: {case['arr']} got {dut.result.value.integer}, expected {case['expected']}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")