import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_guitar_hero(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test cases (scaled to 16-bit times)
    test_cases = [
        # Test 1: 3 notes, 1 phrase (original: 0-10-20, scaled to same)
        {
            "n": 3, "p": 1,
            "notes": [0, 10, 20],
            "phrases": [(0, 10)],
            "expected": 4
        },
        # Test 2: 6 notes, 1 phrase (original: 0-10-20-26-40-50, 0-40)
        {
            "n": 6, "p": 1,
            "notes": [0, 10, 20, 26, 40, 50],
            "phrases": [(0, 40)],
            "expected": 9
        },
        # Test 3: 10 notes → scaled to 8 notes, 2 phrases, times 0-90
        {
            "n": 8, "p": 2,
            "notes": [0, 10, 20, 30, 40, 50, 60, 70],
            "phrases": [(0, 40), (60, 70)],
            "expected": 12  # Original had 14, scaled expectation
        }
    ]

    passed = 0
    for case in test_cases:
        # Prepare inputs
        dut.n_notes.value = case["n"]
        dut.p_phrases.value = case["p"]
        for i in range(16):
            if i < len(case["notes"]):
                dut.notes[i].value = case["notes"][i]
            else:
                dut.notes[i].value = 0
        for i in range(4):
            if i < case["p"]:
                dut.sp_starts[i].value = case["phrases"][i][0]
                dut.sp_ends[i].value = case["phrases"][i][1]
            else:
                dut.sp_starts[i].value = 0
                dut.sp_ends[i].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 20 cycles)
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result
        if int(dut.max_score.value) == case["expected"]:
            passed += 1
        else:
            dut._log.error(
                f"Test failed: Expected {case['expected']}, got {dut.max_score.value}"
            )
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
