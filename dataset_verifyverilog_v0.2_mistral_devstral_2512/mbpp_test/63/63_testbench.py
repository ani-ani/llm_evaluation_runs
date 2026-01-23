import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_difference(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_pairs.value = 0
    for i in range(8):
        dut.pairs[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [(3,5), (1,7), (10,3), (1,2)] -> max diff = 7
    print("Test 1: [(3,5), (1,7), (10,3), (1,2)]")
    dut.num_pairs.value = 4
    dut.pairs[0].value = 3  # a0
    dut.pairs[1].value = 5  # b0
    dut.pairs[2].value = 1  # a1
    dut.pairs[3].value = 7  # b1
    dut.pairs[4].value = 10 # a2
    dut.pairs[5].value = 3  # b2
    dut.pairs[6].value = 1  # a3
    dut.pairs[7].value = 2  # b3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for completion (4 pairs + overhead)
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.max_diff.value == 7, f"Expected 7, got {int(dut.max_diff.value)}"
    print(f"  Result: {int(dut.max_diff.value)} - PASS")
    
    # Test 2: [(4,6), (2,17), (9,13), (11,12)] -> max diff = 15
    print("Test 2: [(4,6), (2,17), (9,13), (11,12)]")
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.num_pairs.value = 4
    dut.pairs[0].value = 4
    dut.pairs[1].value = 6
    dut.pairs[2].value = 2
    dut.pairs[3].value = 17
    dut.pairs[4].value = 9
    dut.pairs[5].value = 13
    dut.pairs[6].value = 11
    dut.pairs[7].value = 12
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.max_diff.value == 15, f"Expected 15, got {int(dut.max_diff.value)}"
    print(f"  Result: {int(dut.max_diff.value)} - PASS")
    
    # Test 3: [(12,35), (21,27), (13,23), (41,22)] -> max diff = 23
    print("Test 3: [(12,35), (21,27), (13,23), (41,22)]")
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.num_pairs.value = 4
    dut.pairs[0].value = 12
    dut.pairs[1].value = 35
    dut.pairs[2].value = 21
    dut.pairs[3].value = 27
    dut.pairs[4].value = 13
    dut.pairs[5].value = 23
    dut.pairs[6].value = 41
    dut.pairs[7].value = 22
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.max_diff.value == 23, f"Expected 23, got {int(dut.max_diff.value)}"
    print(f"  Result: {int(dut.max_diff.value)} - PASS")
    
    print("
All tests passed!")
