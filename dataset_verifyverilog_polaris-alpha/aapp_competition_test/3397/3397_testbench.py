import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools
import random

@cocotb.test()
async def test_dog_feeding(dut):
    # Clock generator
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases (original + adapted)
    test_cases = [{
        "id": 1,
        "n": 2,
        "m": 3,
        "times": [
            [2, 100, 10, 0, 0, 0],
            [100, 1, 10, 0, 0, 0],
            [0]*6,
            [0]*6
        ],
        "expected": 0
    }, {
        "id": 2,
        "n": 3,
        "m": 3,
        "times": [
            [100, 20, 30, 0, 0, 0],
            [10, 90, 80, 0, 0, 0],
            [99, 90, 98, 0, 0, 0],
            [0]*6
        ],
        "expected": 12
    }, {
        "id": 3,
        "n": 4,
        "m": 4,
        "times": [
            [5,5,5,5,0,0],
            [5,5,5,5,0,0],
            [5,5,5,5,0,0],
            [5,5,5,5,0,0]
        ],
        "expected": 0
    }]
    
    passed = 0
    for test in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = test["n"]
        dut.m.value = test["m"]
        for dog in range(4):
            for bowl in range(6):
                sig = getattr(dut, f"eating_times_{dog}_{bowl}")
                sig.value = test["times"][dog][bowl]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.result.value == test["expected"]:
            passed += 1
            dut._log.info(f"Test {test['id']} passed")
        else:
            dut._log.error(f"Test {test['id']} FAILED: Got {dut.result.value}, expected {test['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)