import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.handle import Force

@cocotb.test()
async def test_min_transactions(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases: (m, n, receipts, expected_tx)
    test_cases = [
        (4, 2, [(0,1,1), (2,3,1)], 2),  # Original case scaled down
        (5, 5, [(0,1,3),(1,2,3),(2,3,3),(3,4,3),(4,0,3)], 0),  # Circular payments
        (5, 4, [(0,1,10),(0,2,10),(0,3,10),(0,4,10)], 4),  # Central payer
        (2, 1, [(0,1,50)], 1),  # Simple two-person
        (3, 3, [(0,1,10),(1,2,10),(2,0,10)], 0)  # Triangular cycle
    ]

    passed = 0
    dut._log.info(\\\"Starting tests\\\")

    for m, n, receipts, expected in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.m_in.value = m
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Feed receipts
        for a,b,p in receipts:
            dut.a_in.value = a
            dut.b_in.value = b
            dut.p_in.value = p
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        dut.data_valid.value = 0

        # Wait for computation (max 60 cycles)
        for _ in range(60):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, f\\\"Timeout for test case {receipts}\\\"

        # Check result
        if dut.tx_count.value == expected:
            passed += 1
        else:
            dut._log.error(f\\\"Test failed: M={m}, N={n}, receipts={receipts}\\\\\\
                          Expected={expected}, Got={dut.tx_count.value}\\\")

        # Wait for done to deassert
        await RisingEdge(dut.clk)

    dut._log.info(f\\\"{passed}/{len(test_cases)} tests passed\\\")
    assert passed == len(test_cases)