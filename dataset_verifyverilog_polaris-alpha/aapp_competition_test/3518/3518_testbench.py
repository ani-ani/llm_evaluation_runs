import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_min_co2_matcher(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0

    await reset()

    # Test Case 1: Impossible (5 students)
    # Adapt to n=4 with invalid pairing
    test_case1 = {
        "n": 4,
        "m": 2,
        "p": [1, 3, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "q": [2, 4, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "c": [375, 283, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "expected_co2": 0,
        "expected_impossible": 1
    }

    # Test Case 2: 6 students valid pairing (adapted)
    test_case2 = {
        "n": 6,
        "m": 4,
        "p": [1,2,3,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "q": [2,3,4,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "c": [300, 300, 300, 300, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        "expected_co2": 900,
        "expected_impossible": 0
    }

    test_cases = [test_case1, test_case2]
    passed = 0

    for case in test_cases:
        # Load inputs
        dut.n.value = case["n"]
        dut.m.value = case["m"]
        for i in range(28):
            dut.p[i].value = case["p"][i]
            dut.q[i].value = case["q"][i]
            dut.c[i].value = case["c"][i]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        timeout = 1000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        if timeout == 0:
            dut._log.error("Test timed out")
        else:
            if dut.impossible.value == case["expected_impossible"]:
                if dut.impossible.value or dut.min_co2.value == case["expected_co2"]:
                    passed += 1
                else:
                    dut._log.error(f"CO2 mismatch: Got {dut.min_co2.value}, Expected {case['expected_co2']}")
            else:
                dut._log.error(f"Impossible flag mismatch: Got {dut.impossible.value}, Expected {case['expected_impossible']}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")