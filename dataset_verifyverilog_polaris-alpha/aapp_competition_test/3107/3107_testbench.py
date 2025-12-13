import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def truck_encounter_test(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 1 (trucks 1&2) - Expect 1 encounter
    truck1 = [3, 1, 3, 1]   # 3 cities, 2 segments
    truck2 = [2, 2, 1]      # 2 cities, 1 segment
    await run_simulation_case(dut, truck1, truck2, 1)

    # Test Case 2: Sample Input 1 (trucks 3&1) - Expect 2 encounters
    truck1 = [3, 30, 10, 30]  # 3 cities (scaled)
    truck2 = [3, 10, 30, 10]  # 3 cities (scaled)
    await run_simulation_case(dut, truck1, truck2, 2)

    # Test Case 3: Sample Input 2 - Expect 3 encounters
    truck1 = [4, 10, 60, 30, 60]  # Original: 1,6,3,6
    truck2 = [7, 30, 40, 20, 60, 50, 60, 10]  # Simplified to 4 segments
    await run_simulation_case(dut, truck1[:4], truck2[:8], 3)

    dut._log.info("3/3 tests passed")

async def run_simulation_case(dut, route1, route2, expected):
    # Load truck data (maximum 4 segments)
    dut.truck1_segments.value = len(route1) - 1
    dut.truck2_segments.value = len(route2) - 1
    for i in range(4):
        dut.truck1_route[i].value = route1[i] if i < len(route1) else 0
        dut.truck2_route[i].value = route2[i] if i < len(route2) else 0

    # Start simulation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (max 4200 cycles)
    for _ in range(4200):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        assert False, "Simulation timed out"

    # Verify result
    assert dut.encounter_count.value == expected, \\
        f"Expected {expected} encounters, got {dut.encounter_count.value}"
    await RisingEdge(dut.clk)
