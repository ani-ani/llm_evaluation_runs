import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def lamp_test(dut):
    clock = Clock(dut.clk, 10, units="ns") 
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (adapted to n<=4, k<=8)
    test_cases = [
        # Sample input 1 (possible)
        {
            "grid_size": 3,
            "lamp_reach": 2,
            "num_lamps": 5,
            "rows": [1,1,3,3,2],
            "cols": [1,3,1,3,2],
            "expected": 1
        },
        # Sample input 2 (impossible)
        {
            "grid_size": 3,
            "lamp_reach": 2,
            "num_lamps": 6,
            "rows": [1,1,1,3,3,3],
            "cols": [1,2,3,1,2,3],
            "expected": 0
        },
        # Edge case: single lamp
        {
            "grid_size": 4,
            "lamp_reach": 1,
            "num_lamps": 1,
            "rows": [2],
            "cols": [2],
            "expected": 1
        }
    ]

    passed = 0
    for tc in test_cases:
        # Load inputs
        dut.grid_size.value = tc["grid_size"]
        dut.lamp_reach.value = tc["lamp_reach"]
        dut.num_lamps.value = tc["num_lamps"]
        for i in range(8):
            if i < tc["num_lamps"]:
                dut.lamp_rows[i].value = tc["rows"][i]
                dut.lamp_cols[i].value = tc["cols"][i]
            else:
                dut.lamp_rows[i].value = 0
                dut.lamp_cols[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == tc["expected"]:
            passed += 1
        else:
            dut._log.error(
                f"Failed: n={tc["grid_size"]} r={tc["lamp_reach"]} 
                k={tc["num_lamps"]} => {dut.result.value} (expected {tc["expected"]})"
            )
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)