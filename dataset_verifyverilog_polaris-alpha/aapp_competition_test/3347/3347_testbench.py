import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_gold_store(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(20, units="ns")
    
    # Original test case 1 (n=5)
    test1 = {
        "n": 5,
        "t_i": [5,5,3,5,6],
        "h_i": [8,6,4,13,10],
        "expected": 3
    }
    
    # Original test case 2 (n=5)
    test2 = {
        "n": 5,
        "t_i": [5,6,2,3,4],
        "h_i": [10,15,7,3,11],
        "expected": 4
    }
    
    test_cases = [test1, test2]
    passed = 0
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):  # Clear all inputs
        setattr(dut, f"t_i_{i}", 0)
        setattr(dut, f"h_i_{i}", 0)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for test in test_cases:
        # Load data
        dut.n.value = test["n"]
        for i in range(8):
            t_val = test["t_i"][i] if i < test["n"] else 0
            h_val = test["h_i"][i] if i < test["n"] else 0
            getattr(dut, f"t_i_{i}").value = t_val
            getattr(dut, f"h_i_{i}").value = h_val
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.max_count.value == test["expected"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {test['expected']}, got {dut.max_count.value}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)