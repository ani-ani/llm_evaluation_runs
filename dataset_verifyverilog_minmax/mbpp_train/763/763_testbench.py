import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_min_diff(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Original test cases padded to 8 elements
        {"arr": [1,5,3,19,18,25,0,0], "count":6, "expected":1},
        {"arr": [4,3,2,6,0,0,0,0], "count":4, "expected":1},
        {"arr": [30,5,20,9,0,0,0,0], "count":4, "expected":4},
        # Added edge cases
        {"arr": [10,10,10,10,10,10,10,10], "count":8, "expected":0},
        {"arr": [1,100,2,200,3,0,0,0], "count":5, "expected":1}
    ]
    
    passed = 0
    for case in test_cases:
        # Prepare inputs
        for i in range(8):
            dut.array_in[i].value = case["arr"][i]
        dut.element_count.value = case["count"]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        timeout = 64
        while (dut.done.value != 1 and timeout > 0):
            await RisingEdge(dut.clk)
            timeout -= 1
        
        # Check results
        if timeout == 0:
            dut._log.error(f"FAIL: No done signal received for case {case}")
            continue
        
        if dut.min_diff.value == case["expected"]:
            dut._log.info(f"PASS: {case['arr']} (count={case['count']}) => {dut.min_diff.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {case['arr']} (count={case['count']}) => {dut.min_diff.value}, expected {case['expected']}")
    
    dut._log.info(f"Final result: {passed}/{len(test_cases)} tests passed")