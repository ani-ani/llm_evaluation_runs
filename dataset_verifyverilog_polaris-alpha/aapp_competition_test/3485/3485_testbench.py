import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

# Helper function to convert float to Q16.16 format
def float_to_q16_16(val):
    return int(val * (2**16)) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def q16_16_to_float(val):
    if val >= 0x80000000:
        val = val - 0x100000000
    return val / (2**16)

@cocotb.test()
async def test_max_payout(dut):
    # Create clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (card_count followed by up to 8 cards)
    test_cases = [
        (5, [10, 10, -10, -4, 10, 0,0,0], float_to_q16_16(10.0)),  # Sample 1
        (4, [-3, -1, -4, -1,0,0,0,0], float_to_q16_16(0.0)),      # Sample 2
        (5, [5,7,-10,-4,3,0,0,0], float_to_q16_16(6.0)),          # Sample 3
        (1, [100], float_to_q16_16(100.0)),                       # Edge case single card
        (3, [-5, -10, -3], float_to_q16_16(0.0))                 # All negative cards
    ]

    dut._log.info("Starting tests")
    passed = 0
    total = len(test_cases)

    for (count, cards, expected) in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.card_count.value = count
        dut.card0.value = int(cards[0])
        dut.card1.value = int(cards[1])
        dut.card2.value = int(cards[2])
        dut.card3.value = int(cards[3])
        dut.card4.value = int(cards[4])
        dut.card5.value = int(cards[5])
        dut.card6.value = int(cards[6])
        dut.card7.value = int(cards[7])

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal (max 100 cycles)
        cycles = 0
        while not int(dut.done.value) and cycles < 100:
            await RisingEdge(dut.clk)
            cycles += 1

        if cycles >= 100:
            dut._log.error("Test timed out waiting for done")
            continue

        # Parse result and compare
        result_q = dut.max_avg.value.signed_integer
        result_float = q16_16_to_float(result_q)
        expected_float = q16_16_to_float(expected)

        # Compare with tolerance (due to fixed-point prec)
        if abs(result_float - expected_float) < 1e-3:
            passed += 1
        else:
            dut._log.error(f"Fail: count={count}, cards={cards}
                Got={result_float:.6f} Q={result_q:08X}, Expected={expected_float:.6f} Q={expected:08X}")
     
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total