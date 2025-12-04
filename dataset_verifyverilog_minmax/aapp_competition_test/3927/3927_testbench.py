import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_weight_id(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (4, [1,4,2,2], 2),
        (2, [1,1], 2),
        (3, [2,2,1], 2),
        (1, [1], 1),
        (3, [1,1,1], 3)
    ]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for (n_val, weights, expected) in test_cases:
        # Pad weights to 8 elements
        padded = weights + [0]*(8 - len(weights))
        flat = sum([(w << (4*i)) for i,w in enumerate(padded)])
        dut.n.value = n_val
        dut.weights.value = flat
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done (100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: n={n_val}, weights={weights} => {dut.result.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
