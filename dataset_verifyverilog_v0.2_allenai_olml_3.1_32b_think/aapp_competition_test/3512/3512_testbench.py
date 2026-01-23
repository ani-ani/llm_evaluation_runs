import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_tsp_solver(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    # Initialize distances (Example 1: N=3, but we scale to N=4 logic. We will use a 4-city case)
    # Let's construct a 4-city case adapted from logic or just stick to the prompt's N=4 logic.
    # Python Example 1: 3 cities. Example 2: 4 cities.
    # Example 2 Input:
    # 0 15 7 8
    # 15 0 16 9
    # 7 16 0 12
    # 8 9 12 0
    # Output: 31
    # Let's use Example 2 distances for the test.
    # Mapping:
    # 0-1: 15, 0-2: 7, 0-3: 8
    # 1-2: 16, 1-3: 9
    # 2-3: 12

    dut.city_distance_0_1.value = 15
    dut.city_distance_0_2.value = 7
    dut.city_distance_0_3.value = 8
    dut.city_distance_1_2.value = 16
    dut.city_distance_1_3.value = 9
    dut.city_distance_2_3.value = 12

    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (with timeout)
    cycles_waited = 0
    while not dut.done.value and cycles_waited < 2000:
        await RisingEdge(dut.clk)
        cycles_waited += 1

    if cycles_waited >= 2000:
        raise TestFailure("Module did not finish in reasonable time")

    # Check result
    result = int(dut.min_cost.value)
    expected = 31
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    print(f"Test passed: Result {result} matches expected {expected}")