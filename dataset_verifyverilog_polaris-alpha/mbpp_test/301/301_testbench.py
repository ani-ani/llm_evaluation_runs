import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_depth_calculator(dut):
    # Create test tree structures
    test_cases = [
        # Test 1: Depth 4
        {'nodes': 5, 'data': 0x0010_0210_0320_0430_0000, 'expected': 4},
        # Test 2: Depth 2
        {'nodes': 3, 'data': 0x0010_0210_0300_0000_0000, 'expected': 2},
        # Test 3: Depth 3
        {'nodes': 4, 'data': 0x0010_0210_0320_0000_0000, 'expected': 3},
        # Edge: Single node
        {'nodes': 1, 'data': 0x0000_0000_0000_0000_0000, 'expected': 1},
        # Over-depth protection (input would exceed max)
        {'nodes': 8, 'data': 0x0010_0210_0320_0430_0540_0650_0760_0000, 'expected': 8}
    ]

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for case in test_cases:
        dut.max_nodes.value = case['nodes']
        dut.node_data.value = case['data']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)

        if dut.depth_result.value == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Depth {dut.depth_result.value} (expected {case['expected']})")
        else:
            dut._log.error(f"FAIL: Got {dut.depth_result.value}, expected {case['expected']}")

        # Clear for next test
        await RisingEdge(dut.clk)

    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")