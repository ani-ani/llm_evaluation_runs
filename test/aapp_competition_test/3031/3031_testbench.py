import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_good_nodes(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled)
    test_data = [
        (
            # Sample Input 1 (scaled)
            7,
            [1,2,3,4,5,6,6],
            [3,3,4,5,6,7,8],
            [1,1,3,4,3,2,2],
            0b00111100  # Nodes 3,4,5,6 (bits 2-5)
        ),
        (
            # Sample Input 2 (scaled)
            7,
            [1,1,2,2,3,5,7],
            [2,3,4,7,5,6,8],
            [2,1,3,1,2,2,1],
            0b00000000  # No good nodes
        ),
        # Removed larger cases due to size constraint
    ]
    
    # Initialize and reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_data)
    
    for edge_count, a_nodes, b_nodes, colors, expected in test_data:
        # Load inputs
        dut.edge_count.value = edge_count
        for i in range(8):
            dut.node_a[i].value = a_nodes[i] if i < len(a_nodes) else 0
            dut.node_b[i].value = b_nodes[i] if i < len(b_nodes) else 0
            dut.color[i].value = colors[i] if i < len(colors) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.good_nodes.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed! Input: edges=%d, nodes=%s, colors=%s
  Expected: 0b%08b  Got: 0b%08b" % 
                (edge_count, str(a_nodes), str(colors), expected, dut.good_nodes.value))
        
        await ClockCycles(dut.clk, 3)  # Reset interval
    
    dut._log.info("%d/%d tests passed" % (passed, total))