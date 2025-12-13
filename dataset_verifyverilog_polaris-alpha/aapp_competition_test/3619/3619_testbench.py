import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_team_selector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test case 1: k=1, n=2 (employees 0 and 1)
        {"k":1,"n":2,"s":[1000,1], "p":[1,1000], "r":[0,1], "expected":0.001},
        # Test case 2: k=2, n=3
        {"k":2,"n":3,"s":[1,1,1], "p":[100,200,300], "r":[0,0,0], "expected":250.000},
        # Test case 3: k=2, n=3 (invalid recommender case)
        {"k":2,"n":3,"s":[1,1,1], "p":[1000,1000,1000], "r":[0,1,2], "expected":1000.000/1 + 1000.000/1} # Only CEO+employee0 valid
    ]
    passed = 0
    for test_case in test_cases:
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test data
        dut.k.value = test_case["k"]
        dut.n.value = test_case["n"]
        for i in range(8):
            dut.s_arr[i].value = test_case["s"][i] if i < len(test_case["s"]) else 0
            dut.p_arr[i].value = test_case["p"][i] if i < len(test_case["p"]) else 0
            dut.r_arr[i].value = test_case["r"][i] if i < len(test_case["r"]) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Convert Q16.16 to float
        actual_float = dut.max_ratio.value / 65536.0
        # Round to 3 decimal places (like Python)
        actual_rounded = round(actual_float, 3)
        expected_r = round(test_case["expected"], 3)
        if actual_rounded == expected_r:
            passed += 1
        else:
            dut._log.error(f"Test failed: k={test_case['k']} n={test_case['n']}
                Got {actual_rounded:.3f}, expected {expected_r:.3f}
                Raw Q16.16: 0x{dut.max_ratio.value:x}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
