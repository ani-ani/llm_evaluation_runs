import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_recorder(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled from originals)
    test_cases = [
        # Original sample 1 (n=3,k=1 -> max 2)
        {"n":3, "k":1, "shows": [(1,2),(2,3),(2,3)], "expected":2},
        # Original sample 2 (n=4,k=1 -> max 3)
        {"n":4, "k":1, "shows": [(1,3),(4,6),(7,8),(2,5)], "expected":3},
        # Original 5 2 -> max 3 (ordered as (1,4),(2,7),(3,8),(5,9),(6,10))
        {"n":5, "k":2, "shows": [(1,4),(5,9),(2,7),(3,8),(6,10)], "expected":3},
        # Edge case 1: all shows same time
        {"n":3, "k":2, "shows": [(1,2),(1,2),(1,2)], "expected":2},
        # Edge case 2: k=4, n=8
        {"n":8, "k":4, "shows": [(i*2,i*2+1) for i in range(8)], "expected":8}
    ]
    
    passed = 0
    for tc in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = tc["n"]
        dut.k.value = tc["k"]
        for i in range(16):  # Initialize all to 0
            dut.show_times[i].value = 0
        for idx, (s,e) in enumerate(tc["shows"]):
            dut.show_times[2*idx].value = s
            dut.show_times[2*idx+1].value = e
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 72 cycles + margin)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"
        
        # Check result
        actual = dut.count.value.integer
        if actual == tc["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d k=%d shows=%s -> got %d expected %d" % \
                          (tc["n"], tc["k"], str(tc["shows"]), actual, tc["expected"]))
        
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))