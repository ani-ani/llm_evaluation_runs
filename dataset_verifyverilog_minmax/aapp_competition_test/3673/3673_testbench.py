import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools

@cocotb.test()
async def test_arrow_reconstruction(dut):
    # Adapted test cases (extended to 16 elements with identity mapping)
    test_cases = [
        {
            "input": [3,4,5,6,1,2,7,8,9,10,11,12,13,14,15,16],
            "K": 2,
            "expected": [5,6,1,2,3,4,7,8,9,10,11,12,13,14,15,16]
        },
        {
            "input": [3,4,1,2,5,6,7,8,9,10,11,12,13,14,15,16],
            "K": 2,
            "expected": [2,3,4,1,5,6,7,8,9,10,11,12,13,14,15,16]
        }
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        # Apply inputs
        dut.start.value = 0
        dut.K.value = tc["K"]
        for i in range(16):
            dut.a[i].value = tc["input"][i] - 1  # 0-based indexing in Verilog
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check outputs (convert back to 1-based)
        success = True
        err_msg = ""
        for i in range(16):
            expected = tc["expected"][i] - 1
            actual = dut.arrows[i].value.integer
            if actual != expected:
                success = False
                err_msg += f"Mismatch at index {i}: Expected {expected+1}, got {actual+1}
"
        
        if success:
            passed += 1
        else:
            dut._log.error(f"Test failed for K={tc['K']}, input={tc['input']}
{err_msg}")
        
        # Reset for next test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\\
Test summary: {passed}/{total} tests passed")
    if passed < total:
        dut._log.error("Some tests failed")
    else:
        dut._log.info("All tests passed")