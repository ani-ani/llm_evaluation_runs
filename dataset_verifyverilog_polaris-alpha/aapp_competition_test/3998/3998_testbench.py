import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_rating_equalizer(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())

    async def reset():"""Reset routine"""
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(10, units="ns")
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases (n=4 players)
    test_cases = [
        # Original test1 scaled to 4 players
        (4, [4,5,1,7], 1),
        # Original test2 splits
        (2, [1,2], 0),
        # Equal already
        (4, [5,5,5,5], 5),
        # Max drop case
        (4, [8,8,6,6], 6)
    ]

    passed = 0
    total = len(test_cases)

    for n_players, ratings, expected_R in test_cases:
        # Apply test inputs (only first n_players used)
        dut.start.value = 0
        dut.r0.value = ratings[0] if n_players >=1 else 0
        dut.r1.value = ratings[1] if n_players >=2 else 0
        dut.r2.value = ratings[2] if n_players >=3 else 0
        dut.r3.value = ratings[3] if n_players >=4 else 0

        await reset()
        await RisingEdge(dut.clk)

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Process cycles
        cycles = 0
        max_cycles = 100
        observed_matches = []
        while cycles < max_cycles and not dut.done.value:
            if dut.valid_match.value:
                observed_matches.append(dut.match_vec.value.binstr)
            cycles += 1
            await RisingEdge(dut.clk)

        # Check outcome
        if dut.done.value and dut.final_R.value == expected_R:
            passed +=1
            dut._log.info(f"Test passed: R={dut.final_R.value}, cycles={cycles}")
        else:
            if not dut.done.value:
                dut._log.error(f"Test timed out after {max_cycles} cycles")
            else:
                dut._log.error(f"Bad R: {dut.final_R.value} vs expected {expected_R}")
    dut._log.info(f"{passed}/{total} tests passed")"