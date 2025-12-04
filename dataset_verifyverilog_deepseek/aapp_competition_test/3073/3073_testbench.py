import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_knight(dut):
    clock = Clock(dut.clk, 10, units="ns") # Create 100MHz clock
    cocotb.start_soon(clock.start()) # Start clock generator

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await Timer(15, units="ns")

    # Test Case 1 (Modified): Valid path requires buying both cards
    test1_cards = [[
        3,  3,  2,  2, 100,  # Card 0 (start)
        1,  1,  1,  1, 500   # Card 1
    ]]
    expected1 = 600

    # Test Case 2 (Modified): Only need first card
    test2_cards = [[
        2,  0,  2,  1, 100,  # Card 0 (start)
        6,  0,  8,  1, 1    # Card 1 (unused)
    ]]
    expected2 = 100

    # Test Case 3 (Modified): Impossible path
    test3_cards = [[
        1,    0, 100, 50, 100,
        50,  50, 50, 25, 100,
        260, 0,  20, 30, 123
    ]]
    expected3 = 0xFFFF

    test_cases = [(test1_cards[0], expected1), (test2_cards[0], expected2), (test3_cards[0], expected3)]
    passed = 0

    for card_data, expected in test_cases:
        # Load card data (max 256 cards in this interface)
        for i in range(len(card_data)//5):
            idx = i * 5
            dut.card_data[i][0].value = int(card_data[idx])
            dut.card_data[i][1].value = int(card_data[idx+1])
            dut.card_data[i][2].value = int(card_data[idx+2])
            dut.card_data[i][3].value = int(card_data[idx+3])
            dut.card_data[i][4].value = int(card_data[idx+4])
        dut.num_cards.value = len(card_data)//5
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while (dut.done.value == 0):
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Check results
        actual = dut.min_cost.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got cost {actual}, expected {expected}")
        await Timer(20, units="ns") # Allow visibility

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")