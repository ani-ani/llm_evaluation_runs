import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def fence_painter_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Utility to pack offer data (color, start, end)
    def pack_offer(color, start, end):
        return (color << 8) | (start << 4) | end

    # Test case 1 (adapted Sample 1): 2 offers, 2 colors
    test_offers1 = [pack_offer(1,0,7),  # BLUE 1-8 (0-7 sections)
                    pack_offer(2,8,15)] # RED 9-16 (8-15 sections)
    # Others default to 0 (unused)
    test_offers1 += [0]*(8 - len(test_offers1))
    await RisingEdge(dut.clk)
    dut.num_offers.value = 2
    for i in range(8):
        dut.offer_data[i].value = test_offers1[i]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for processing (worst case 256 cycles)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.impossible.value == 0, "Test1 should be possible"
    assert dut.min_count.value == 2, f"Test1 got {dut.min_count.value}, expected 2"

    # Test case 2 (Sample 3 - impossible case):
    # 4 offers that can't be covered with 3 colors
    test_offers2 = [pack_offer(1,0,5),   # 1-6
                    pack_offer(2,4,9),   # 5-10
                    pack_offer(3,8,13),  # 9-14
                    pack_offer(4,12,15)] # 13-16
    test_offers2 += [0]*(8 - len(test_offers2))
    dut.num_offers.value = 4
    for i in range(8):
        dut.offer_data[i].value = test_offers2[i]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.impossible.value == 1, "Test2 should be impossible"

    # Test case 3 (Sample 5): Minimal solution possible
    test_offers3 = [pack_offer(1,0,11),  # 1-12
                    pack_offer(2,8,15),  # 9-16
                    pack_offer(3,6,13)]  # 7-14
    test_offers3 += [0]*(8 - len(test_offers3))
    dut.num_offers.value = 3
    for i in range(8):
        dut.offer_data[i].value = test_offers3[i]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.impossible.value == 0, "Test3 should be possible"
    assert dut.min_count.value.integer == 2, f"Test3 got {dut.min_count.value}, expected 2"

    dut._log.info("3/3 tests passed")