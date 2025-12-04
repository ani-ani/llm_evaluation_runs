import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_gig_scheduler(dut):
    # Generate clock (100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(15, units="ns")

    # Test case 1: Original sample input (expected 33)
    roads_a = 0b01_00_00_00  # [1,0,0,0] (packed 4x2b)
    roads_b = 0b10_00_00_00  # [2,0,0,0]
    roads_t = (10 << 48) | 0  # [10,0,0,0] (16-bit chunks)
    gigs_v = 0b01_01_10_00     # [1,1,2,0] (venue list)
    gigs_s = (4 << 48) | (6 << 32) | (10 << 16) | 0  # [4,6,10,0]
    gigs_e = (6 << 48) | (10 << 32) | (30 << 16) | 0 # [6,10,30,0]
    gigs_m = (6 << 48) | (5 << 32) | (33 << 16) | 0  # [6,5,33,0]

    await run_test_case(dut, roads_a, roads_b, roads_t, gigs_v, gigs_s, gigs_e, gigs_m, 33)

    # Test case 2: Modified second sample (expected 70)
    roads_a = 0b01_00_00_00
    roads_b = 0b10_00_00_00
    roads_t = (10 << 48) | 0
    gigs_v = 0b01_01_10_00  # [1,1,2,0]
    gigs_s = (4 << 48) | (6 << 32) | (10 << 16) | 0
    gigs_e = (6 << 48) | (10 << 32) | (30 << 16) | 0
    gigs_m = (30 << 48) | (40 << 32) | (50 << 16) | 0  # [30,40,50,0]
    await run_test_case(dut, roads_a, roads_b, roads_t, gigs_v, gigs_s, gigs_e, gigs_m, 70)

    dut._log.info("2/2 tests passed")

async def run_test_case(dut, ra, rb, rt, gv, gs, ge, gm, expected):
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Apply inputs
    dut.road_a.value = ra
    dut.road_b.value = rb
    dut.road_t.value = rt
    dut.gig_v.value = gv
    dut.gig_s.value = gs
    dut.gig_e.value = ge
    dut.gig_m.value = gm
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for computation (22 cycles + 1 for output)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    assert dut.done.value == 1, "Computation timeout"
    assert dut.max_earnings.value.integer == expected, \\
        f"Expected {expected}, got {dut.max_earnings.value.integer}"