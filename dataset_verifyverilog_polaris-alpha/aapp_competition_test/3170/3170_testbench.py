import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_trash(dut):
    # Test case 1: Theta wins scenario (simplified deck)
    test1_input = "A2J4J3TQ"  # Encoded as [4'hA,4'h2,4'hJ,4'h4,4'hJ,4'h3,4'hT,4'hQ]

    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.card_in.value = 0
    dut.card_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Feed test deck
    for card in test1_input:
        # Convert ASCII to 4-bit encoding (simplified mapping)
        card_val = 0
        if card == "A": card_val = 1
        elif card == "J": card_val = 11
        elif card == "T": card_val = 10
        elif card in "234": card_val = int(card)
        else: card_val = 15  # Q/K = invalid
        
        dut.card_in.value = card_val
        dut.card_valid.value = 1
        await RisingEdge(dut.clk)
        dut.card_valid.value = 0
        while not (dut.theta_win.value or dut.friend_win.value):
            await RisingEdge(dut.clk)
        if dut.theta_win.value:
            dut._log.info("Theta won test1")
        else:
            assert False, "Test1 should result in Theta win"

    # Additional test cases...
    dut._log.info("1/1 tests passed")