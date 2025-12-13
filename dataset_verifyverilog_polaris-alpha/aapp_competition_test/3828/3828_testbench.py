import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_train_sorter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # (n, car_list, expected_moves)
        (5, [4,1,2,5,3], 2),  # original sample
        (4, [4,1,3,2], 2),    # original sample
        (1, [1], 0),          # single car edge case
        (2, [1,2], 0),        # already sorted
        (2, [2,1], 1),        # reverse sorted
        (5, [1,4,2,3,5], 2)
    ]

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for n_val, cars, expected in test_cases:
        # Load inputs
        dut.n.value = n_val
        for i in range(16):
            if i < len(cars):
                dut.car_numbers[i].value = cars[i]
            else:
                dut.car_numbers[i].value = 0
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        result = dut.min_moves.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val}, cars={cars} => {result}, expected {expected}")
        await RisingEdge(dut.clk)
        dut.done.value = 0

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
