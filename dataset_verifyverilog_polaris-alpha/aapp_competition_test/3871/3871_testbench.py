import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_profit(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test case 1 (n=5, m=4)
        {
            "n": 5,
            "l": [4,3,1,2,1],
            "s": [1,2,1,2,1],
            "c": [1,2,3,4,5,6,7,8,9,0,0,0,0,0,0,0],
            "expected": 6
        },
        # Test case 2 (n=2, m=2)
        {
            "n": 2,
            "l": [1,2],
            "s": [0,0],
            "c": [2,1,-100,-100,0,0,0,0,0,0,0,0,0,0,0,0],
            "expected": 2
        },
        # Test case 3 (empty set)
        {
            "n": 0,
            "l": [],
            "s": [],
            "c": [0]*16,
            "expected": 0
        }
    ]
    
    passed = 0
    for test in test_cases:
        # Load inputs
        dut.start.value = 0
        dut.num_candidates.value = test["n"]
        for i in range(8):
            if i < test["n"]:
                dut.l_i[i].value = test["l"][i] if i < len(test["l"]) else 0
                dut.s_i[i].value = test["s"][i] if i < len(test["s"]) else 0
            else:
                dut.l_i[i].value = 0
                dut.s_i[i].value = 0
        for i in range(16):
            dut.c_v[i].value = test["c"][i] if i < len(test["c"]) else 0
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 0
        while dut.done.value == 0 and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 200:
            dut._log.error("Test timed out")
        else:
            result = dut.max_profit.value.signed_integer
            if result == test["expected"]:
                passed += 1
            else:
                dut._log.error(f"Test failed: Got {result}, Expected {test['expected']}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total