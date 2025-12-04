import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
@cocotb.test()
async def test_coin_game(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    # Test cases (d_init, g_init, n_rounds, k_distracted, expected)
    test_cases = [
        (2, 10, 3, 2, 4),   # Original sample 1
        (10, 10, 5, 0, 10), # Original sample 2
        (1, 15, 8, 7, 7),   # Max coins absorption case
        (8, 12, 8, 3, 11)   # Mixed case
    ]
    # Initialize and reset
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    passed = 0
    for idx, (d, g, n, k, expected) in enumerate(test_cases):
        # Apply test inputs
        dut.d_init.value = d
        dut.g_init.value = g
        dut.n_rounds.value = n
        dut.k_distracted.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (10 cycles)
        for _ in range(12):
            await RisingEdge(dut.clk)
        if dut.done.value != 1:
            dut._log.error(f"Test #{idx+1} failed: Done not asserted")
            continue
        if dut.m_coins.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test #{idx+1} failed:
              Input (d={d},g={g},n={n},k={k})
              Got {dut.m_coins.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)