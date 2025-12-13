import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

@cocotb.test()
async def test_monstermind(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4 questions max)
    # Format: (t, n, [wcnt0, wcnt1, wcnt2, wcnt3], expected_score_Q16)
    test_cases = [
        # Sample 1: 4 questions, all wcnt=5 -> total 2 points
        (4, 4, [5,5,5,5], 0x00020000),
        # Sample 2: 3 questions, wcnt=3,4,3 -> ~1.333 points
        (4, 3, [3,4,3,0], 0x00015555),
        # Edge case: t=1 (can only answer questions with wcnt=0)
        (1, 2, [0,0,0,0], 0x00010000)
    ]

    passed = 0
    dut._log.info("Starting tests...")

    for (t_val, n_val, wcnts, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.start.value = 0
        dut.t.value = t_val
        dut.n.value = n_val
        dut.wcnt0.value = wcnts[0]
        dut.wcnt1.value = wcnts[1]
        dut.wcnt2.value = wcnts[2]
        dut.wcnt3.value = wcnts[3]
        await RisingEdge(dut.clk)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        for _ in range(20):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)

        score = dut.expected_score.value.integer
        tolerance = 0x00000100  # Allow 1/256 error
        if abs(score - expected) <= tolerance:
            passed += 1
        else:
            actual_float = score / 65536.0
            expected_float = expected / 65536.0
            dut._log.error(f"Failed: t={t_val} n={n_val} wcnt={wcnts}
  Expected: {expected_float:.6f} ({hex(expected)}), Got: {actual_float:.6f} ({hex(score)})")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)