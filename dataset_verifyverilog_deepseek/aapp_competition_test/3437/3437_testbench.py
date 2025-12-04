import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_tube_pairs(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [{"L1":1000,"L2":2000,"tubes":[100,480,500,550,1000,1400,1500,0],"expected":2930},{"L1":200,"L2":300,"tubes":[100,100,200,200,300,300,0,0],"expected":0}]# Impossible case

    passed = 0
    for test in test_cases:
        # Load inputs
        dut.start.value = 0
        dut.L1.value = test["L1"]
        dut.L2.value = test["L2"]
        for i in range(8):
            dut.tubes[i].value = test["tubes"][i] if i < len(test["tubes"]) else 0

        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done (3 cycles)
        for _ in range(4):
            await RisingEdge(dut.clk)

        # Check outputs
        if test["expected"] == 0:
            if dut.impossible.value == 1:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected impossible but got total {dut.max_total.value}")
        else:
            if dut.max_total.value == test["expected"]:
                passed += 1
            else:
                dut._log.error(f"Test failed: Got {dut.max_total.value}, expected {test['expected']}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")