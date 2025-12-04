import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_gas_station(dut):
    # Generate clock (100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(15, units="ns")

    # Test cases (scaled down from original examples)
    test_cases = [
        # Input 1: 3 stations, g=10
        {
            'n': 3, 'g': 10, 'd': [1, 2, 11], 'c': [10, 100, 5],
            'expected_cost': 10, 'expected_error': 0
        },
        # Input 2: Impossible (station 13 -> scaled to 14)
        {
            'n': 3, 'g': 10, 'd': [1, 2, 14], 'c': [10, 100, 5],
            'expected_cost': 0xFFFFFFFF, 'expected_error': 1
        },
        # Additional test: Partial refill needed
        {
            'n': 3, 'g': 10, 'd': [1, 10, 12], 'c': [1, 5, 3],
            'expected_cost': 6, 'expected_error': 0
        }
    ]

    passed = 0
    total = len(test_cases)

    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = case['n']
        dut.g.value = case['g']
        for i in range(8):
            if i < case['n']:
                dut.d[i].value = case['d'][i]
                dut.c[i].value = case['c'][i]
            else:
                dut.d[i].value = 0
                dut.c[i].value = 0
        await RisingEdge(dut.clk)

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion (max 256 cycles)
        timeout = 256
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        assert timeout > 0, "Test timeout"
        assert dut.error.value == case['expected_error'],
            f"Error flag mismatch: {dut.error.value} vs {case['expected_error']}"

        if dut.error.value == 0:
            assert dut.total_cost.value == case['expected_cost'],
                f"Cost mismatch: {dut.total_cost.value} vs {case['expected_cost']}"
        else:
            assert dut.total_cost.value == 0xFFFFFFFF, "Error case should output max cost"

        passed += 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")
