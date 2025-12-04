import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_max_inc_subseq(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from original problem (padded to 8 elements)
    test_cases = [
        {"data": [1,101,2,3,100,4,5,0], "n":7, "index":4, "k":6, "expected":11},
        {"data": [1,101,2,3,100,4,5,0], "n":7, "index":2, "k":5, "expected":7},
        {"data": [11,15,19,21,26,28,31,0], "n":7, "index":2, "k":4, "expected":71},
        # Edge case: max_values
        {"data": [255,254,253,252,251,250,249,248], "n":8, "index":3, "k":4, "expected":252+251}
    ]
    
    passed = 0
    for tc in test_cases:
        # Load data
        for i in range(8):
            dut.data[i].value = tc["data"][i] if i < tc["n"] else 0
        
        dut.index.value = tc["index"]
        dut.k.value = tc["k"]
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(75):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        result = dut.max_sum.value.integer
        if result == tc["expected"]:
            passed += 1
            dut._log.info(f"PASS: {tc['expected']} == {result}")
        else:
            dut._log.error(f"FAIL: data={tc['data']}, index={tc['index']}, k={tc['k']}. Got {result}, expected {tc['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")