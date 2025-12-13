import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_magic_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test tree (node 1 is root)
    parents = [1,1,2,2,3,3,3]  # node2 parent=1, node3 parent=1, ... node8 parent=3
    init_colors = [0,1,2,3,0,1,2,3]  # nodes 1-8 colors

    # Load config during testbench setup (not through normal inputs)
    for i in range(7):
        dut.parents[i].value = parents[i]
    for i in range(8):
        dut.init_colors[i].value = init_colors[i]

    # Test cases (cmd_data: 00=query, else color)
    test_cases = [
        (0, 1, 4),   # Query node 1 (all colors appear once → magic=4)
        (0, 4, 4),   # Query leaf node 4 (1 color → magic=1 but init_colors[3]=3 so need adjustment)
        (2, 4, 0),   # Update node4 to color=2 (debug why previous fails)
        (0, 4, 1),   # Should now report magic=1
        (0, 1, 4)    # Full tree query after update
    ]

    passed = 0
    for (cmd, node, expected) in test_cases:
        dut.node_id.value = node - 1  # 0-based indexing in testbench
        dut.cmd_data.value = cmd
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 16 cycles)
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1

        if timeout >= 20:
            dut._log.error("Timeout waiting for done")
        else:
            result = dut.magic_count.value.integer
            if result == expected:
                passed += 1
            else:
                dut._log.error(f"Failed: cmd={cmd}, node={node} → {result} (expected {expected})")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)