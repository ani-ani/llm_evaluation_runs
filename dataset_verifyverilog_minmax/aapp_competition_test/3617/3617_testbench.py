import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

MOD = 1000000007

@cocotb.test()
async def test_pikeman(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (N, T, A, B, C, t0, expected_num, expected_penalty)
    test_cases = [
        (1, 3, 2, 2, 2, 1, 1, 1 % MOD),
        (2, 10, 2, 2, 2, 2, 2, (2+2) % MOD),
        (3, 15, 1, 1, 10, 1, 3, (1+2+3) % MOD),  # Generated sequence: 1,2,3
        (4, 20, 3, 0, 10, 1, 4, (1+1+1+1) % MOD)  # Sequence: 1,1,1,1
    ]

    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for (N, T, A, B, C, t0, exp_num, exp_pen) in test_cases:
        dut.N.value = N
        dut.T.value = T
        dut.A.value = A
        dut.B.value = B
        dut.C.value = C
        dut.t0.value = t0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check outputs
        if dut.num_problems.value == exp_num and dut.penalty.value == exp_pen:
            passed += 1
        else:
            dut._log.error(
                f"Failed: N={N},T={T},A={A},B={B},C={C},t0={t0}" +
                f"  Got num={dut.num_problems.value}, pen={dut.penalty.value}  Expected num={exp_num}, pen={exp_pen}"
            )
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)