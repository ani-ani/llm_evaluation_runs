import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rocket_safety(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    # Scaled test cases (original points adjusted to 16-bit range)
    test_cases = [
        ( # Test 1: YES case (original sample)
            3, 4,
            [0, 0, 2], [0, 2, 0], # Engine1
            [0, 2, 2, 1], [2, 2, 0, 1], # Engine2
            1
        ),
        ( # Test 2: NO case (original sample)
            3, 4,
            [0, 0, 2], [0, 2, 0], # Engine1
            [0, 2, 2, 0], [2, 2, 0, 0], # Engine2
            0
        ),
        ( # Test 3: Edge case - 3 points identity
            3, 3,
            [0, 100, 0], [0, 0, 100],
            [0, 100, 0], [0, 0, 100],
            1
        )
    ]
    await Timer(15, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for (n_val, m_val, e1x, e1y, e2x, e2y, expected) in test_cases:
        dut.start.value = 0
        dut.n.value = n_val
        dut.m.value = m_val
        # Load engine1 points
        for i in range(8):
            if i < len(e1x):
                dut.engine1_x[i].value = e1x[i]
                dut.engine1_y[i].value = e1y[i]
            else:
                dut.engine1_x[i].value = 0
                dut.engine1_y[i].value = 0
        # Load engine2 points
        for i in range(8):
            if i < len(e2x):
                dut.engine2_x[i].value = e2x[i]
                dut.engine2_y[i].value = e2y[i]
            else:
                dut.engine2_x[i].value = 0
                dut.engine2_y[i].value = 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        for _ in range(100):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, "Timeout waiting for done"
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: Expected {expected}, got {dut.result.value}")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
