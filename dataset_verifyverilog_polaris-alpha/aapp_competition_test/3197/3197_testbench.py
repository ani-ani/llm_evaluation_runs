import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_group_trip(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 8 participants with padding)
    test_cases = [
        # Original case 1: all self-referential (n=4 → pad with 1s)
        {"k": 4, "prefs": [0,1,2,3,0,0,0,0], "expected": 4},
        # Original case 2: complex dependencies (n=12 → strip to 8 with trimmed logic)
        {"k": 3, "prefs": [1,2,3,4,5,6,3,6], "expected": 2},
        # Original case 3: dependency chains (n=5 → pad with 1s)
        {"k": 4, "prefs": [1,2,0,4,3,3,3,3], "expected": 3},
        # Edge case: k=1 but valid subset
        {"k": 1, "prefs": [0,0,0,0,0,0,0,0], "expected": 1},
        # Max capacity case
        {"k": 8, "prefs": [7,6,5,4,3,2,1,0], "expected": 8}
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Load inputs
        dut.start.value = 0
        dut.k.value = case["k"]
        for i in range(8):
            dut.preferences[i].value = case["prefs"][i]
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(260):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.max_count.value == case["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: k=%d prefs=%s got %d expected %d" % \
                          (case["k"], str(case["prefs"]), dut.max_count.value, case["expected"]))
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)