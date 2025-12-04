import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_heap_prob(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled from original problems)
    test_data = [
        # 2-node case (1 edge): expected 500000004
        (2, (1,0), (1,1), (1,0), (1,0), 500000004),
        # 4-node chain: a->b->c->d (3 edges) expected 125000001
        (4, (1,0), (1,1), (1,2), (1,3), 125000001),
        # 4-node star (root + 3 children, 3 edges) expected 125000001
        (4, (1,0), (1,1), (1,1), (1,1), 125000001),
    ]

    passed = 0
    for n, *nodes, expected in test_data:
        dut.n.value = n
        dut.b1_value.value, dut.p1_parent.value = nodes[0]
        dut.b2_value.value, dut.p2_parent.value = nodes[1]
        dut.b3_value.value, dut.p3_parent.value = nodes[2]
        dut.b4_value.value, dut.p4_parent.value = nodes[3]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(4):  # wait 4 cycles
            await RisingEdge(dut.clk)
        if dut.done.value != 1:
            dut._log.error("Done signal not asserted")
        else:
            result_val = dut.result.value.integer
            if result_val == expected:
                passed += 1
            else:
                dut._log.error(f"Test failed: Got {result_val}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_data)} tests passed")
    assert passed == len(test_data), "Some tests failed"