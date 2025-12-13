import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_transit(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())  
    dut._log.info("Start test")
    
    # Scaled test cases (original tests unsuitable - resized to 16-day limit)
    test_cases = [
        # Case 1: 15 days, 0 trips, 3 prices (20,15,10) thresh 7+7
        {
            "l": 3, "p": [20,15,10], "d": [7,7],
            "n": 0, "t": 15, "trips": 0,
            "expected": (20*7 + 15*7 + 10*1) # 140+105+10=255
        },
        # Case 2: 15 days, 2 trips ([5-5], [15-15]), same prices
        {
            "l": 3, "p": [20,15,10], "d": [7,7],
            "n": 2, "t": 15, "trips": 0x0505_0F0F,
            "expected": (20*7 + 10*8) # 140 + 80 = 220
        }
    ]
    
    passed = 0
    for test in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.l.value = test["l"]
        # Price array indexing not supported in cocotb? Assign elements directly
        for i in range(8):
            if i < len(test["p"]):
                dut.p[i].value = test["p"][i]
            else: 
                dut.p[i].value = 0
        for i in range(7):
            if i < len(test["d"]):
                d_val = test["d"][i] * (i < (test["l"]-1)) # only valid for lower L-1 indices
                dut.d[i].value = d_val 
            else: 
                dut.d[i].value = 0
        dut.n.value = test["n"]
        dut.t.value = test["t"]
        dut.trips.value = test.get("trips", 0)
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 2*t cycles)
        timeout = 2 * test["t"] + 10
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout <= 0:
            dut._log.error("Calculation timed out")
        else:
            if dut.total_cost.value == test["expected"]:
                passed += 1
                dut._log.info(f"Test passed: got {dut.total_cost.value}")
            else:
                dut._log.error(f"FAIL: Expected {test['expected']}, got {dut.total_cost.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)