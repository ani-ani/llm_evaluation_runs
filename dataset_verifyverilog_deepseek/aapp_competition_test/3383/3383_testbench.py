import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_ice_cream(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test case 1 (scaled from sample 1: n=16 instead of 20)
    test1 = {
        "n": 16,
        "k": 3,
        "a": 5,
        "b": 5,
        "t": [0, 0, 0, 0],
        "u": [[0,-10,0,0], [30,0,0,0], [0,0,0,0], [0,0,0,0]]
    }

    # Test case 2 (original sample 2)
    test2 = {
        "n": 10,
        "k": 1,
        "a": 8,
        "b": 20,
        "t": [5, 0, 0, 0],
        "u": [[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0]]
    }

    tests = [
        (test1, 2.0),  # (input, expected ratio)
        (test2, 0.5)
    ]

    await reset()
    passed = 0

    for test_data, expected in tests:
        # Apply test inputs
        dut.start.value = 0
        dut.n.value = test_data["n"]
        dut.k.value = test_data["k"]
        dut.a.value = test_data["a"]
        dut.b.value = test_data["b"]
        for i in range(4):
            dut.t[i].value = test_data["t"][i]
            for j in range(4):
                dut.u[i][j].value = test_data["u"][i][j]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Convert fixed-point to float
        ratio_raw = dut.max_ratio.value.signed_integer
        ratio_float = ratio_raw / (1 << 16)

        # Check result
        tolerance = 1e-3  # Allow 0.001 error
        if abs(ratio_float - expected) < tolerance:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {ratio_float}, expected {expected}")

    # Edge case: All tastiness <=0 (should output 0)
    await reset()
    test3 = {
        "n": 16,
        "k": 2,
        "a": 10,
        "b": 5,
        "t": [-5, -3, 0, 0],
        "u": [[-10,-20,0,0], [-15,-5,0,0], [0,0,0,0], [0,0,0,0]]
    }
    dut.n.value = test3["n"]
    dut.k.value = test3["k"]
    dut.a.value = test3["a"]
    dut.b.value = test3["b"]
    for i in range(4):
        dut.t[i].value = test3["t"][i]
        for j in range(4):
            dut.u[i][j].value = test3["u"][i][j]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    if dut.max_ratio.value == 0:
        passed += 1
    else:
        dut._log.error(f"Edge case failed: Got {dut.max_ratio.value}, expected 0")

    total_tests = len(tests)+1
    dut._log.info(f"{passed}/{total_tests} tests passed")