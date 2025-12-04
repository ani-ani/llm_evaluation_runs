import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_matrix_sort(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (row-major flattened)
    tests = [
        # Test 1
        {
            "input": [1,2,3, 2,4,5, 1,1,1],
            "expected": [1,1,1, 1,2,3, 2,4,5]
        },
        # Test 2
        {
            "input": [1,2,3, -2,4,-5, 1,-1,1],
            "expected": [-2,4,-5, 1,-1,1, 1,2,3]
        },
        # Test 3
        {
            "input": [5,8,9, 6,4,3, 2,1,4],
            "expected": [2,1,4, 6,4,3, 5,8,9]
        }
    ]

    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for test in tests:
        # Load inputs
        for i, val in enumerate(test["input"]):
            dut.matrix_flat[i].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (5 cycles)
        for _ in range(5):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        result = [dut.sorted_matrix[i].value.signed_integer for i in range(9)]
        if result == test["expected"]:
            passed += 1
            dut._log.info(f"PASS: {test['input']} -> {result}")
        else:
            dut._log.error(f"FAIL: Input={test['input']}")
            dut._log.error(f"  Expected: {test['expected']}")
            dut._log.error(f"  Received: {result}")
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")