import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_prime_pal(dut):
    # Create 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test cases (p, q, expected)
    test_cases = [
        (1, 1, 40),    # 40 primes ≤ 12 pal*1
        (1, 42, 1),    # Immediate match at n=1
        (6, 4, 172),   # Scaled expectation
        (5, 8, 16),    # Edge case where 7 primes vs 6 pal
        (10000, 10000, 40)  # Max input test
    ]
    passed = 0

    for p_val, q_val, expected in test_cases:
        dut.p.value = p_val
        dut.q.value = q_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (1000 cycles + 1)
        for _ in range(1002):
            await RisingEdge(dut.clk)

        # Check result at done assertion
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"Passed test p={p_val} q={q_val}, got {dut.result.value}")
        else:
            dut._log.error(f"FAIL p={p_val} q={q_val}: Expected {expected}, got {dut.result.value}")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)