import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_minimal_deletion(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await Timer(10, units="ns")

    test_cases = [
        # Test case 1 (n=7, expected=4)
        {
            "n": 7,
            "row1": [5,4,3,2,1,6,7,0],
            "row2": [5,5,1,1,3,4,7,0],
            "row3": [3,7,1,4,5,6,2,0],
            "expected": 4
        },
        # Test case 2 (n=4, expected=2)
        {
            "n": 4,
            "row1": [3,1,4,2,0,0,0,0],
            "row2": [3,3,3,3,0,0,0,0],
            "row3": [1,1,1,1,0,0,0,0],
            "expected": 4-2 # Keep cols 0 & 3 ([3,2] -> [2,3]; [3,3]->[3,3]; [1,1]->[1,1])
        },
        # Test case 3 (all columns valid)
        {
            "n": 3,
            "row1": [1,2,3,0,0,0,0,0],
            "row2": [1,2,3,0,0,0,0,0],
            "row3": [1,2,3,0,0,0,0,0],
            "expected": 0
        }
    ]

    passed = 0
    for test_id, test in enumerate(test_cases):
        # Format inputs
        def pack_row(arr):
            val = 0
            for i, v in enumerate(arr):
                val |= (v & 0x7) << (i*3)
            return val
        
        dut.n.value = test["n"]
        dut.row1.value = pack_row(test["row1"])
        dut.row2.value = pack_row(test["row2"])
        dut.row3.value = pack_row(test["row3"])
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while(dut.done.value != 1):
            await RisingEdge(dut.clk)
        
        result = dut.result.value.integer
        if result == test["expected"]:
            dut._log.info(f"Test {test_id+1} passed")
            passed += 1
        else:
            dut._log.error(f"Test {test_id+1} FAILED: Expected {test["expected"]}, got {result}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
    if passed < len(test_cases):
        exit(1)