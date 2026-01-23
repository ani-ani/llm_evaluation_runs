import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_or_path_calculator(dut):
    """Test OR path calculator with sample graphs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.node_count.value = 0
    dut.edge_count.value = 0
    for i in range(16):
        dut.edges[i].value = 0
    dut.query_s.value = 0
    dut.query_t.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Original sample - 4 nodes, 7 edges
    # Edges: (1,2,1), (1,2,3), (1,3,2), (1,4,1), (2,3,4), (2,4,4), (3,4,4)
    # Expected: 1-2:1, 1-3:2, 3-4:3
    
    dut.node_count.value = 4
    dut.edge_count.value = 7
    
    # Pack edges: src[15:12], dst[11:8], weight[7:0] - using 4+4+8=16 bits
    edges = [
        (1, 2, 1),   # src=1, dst=2, w=1   -> 0x1201
        (1, 2, 3),   # src=1, dst=2, w=3   -> 0x1203  
        (1, 3, 2),   # src=1, dst=3, w=2   -> 0x1302
        (1, 4, 1),   # src=1, dst=4, w=1   -> 0x1401
        (2, 3, 4),   # src=2, dst=3, w=4   -> 0x2304
        (2, 4, 4),   # src=2, dst=4, w=4   -> 0x2404
        (3, 4, 4),   # src=3, dst=4, w=4   -> 0x3404
    ]
    
    for i, (src, dst, w) in enumerate(edges):
        # Format: src[3:0] in bits 15:12, dst[3:0] in bits 11:8, weight[7:0] in bits 7:0
        # But we need 16-bit weight, so pack as: src[3:0], dst[3:0], weight[15:0]
        packed = (src << 12) | (dst << 8) | (w & 0xFF)  # Truncating to 8-bit for demo
        # Actually use full 16-bit weight in lower bits: let's use different packing
        # src[3:0] at [15:12], dst[3:0] at [11:8], weight[15:0] would need 24 bits
        # For simplicity, we'll use 8-bit weights in test (scale down problem)
        dut.edges[i].value = packed
    
    # Query 1: 1 to 2
    dut.query_s.value = 1
    dut.query_t.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 50 cycles)
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    assert dut.result.value == 1, f"Test 1a failed: expected 1, got {dut.result.value}"
    print(f"Test 1a (1->2): PASS (got {dut.result.value})")
    
    # Query 2: 1 to 3
    dut.query_s.value = 1
    dut.query_t.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    assert dut.result.value == 2, f"Test 1b failed: expected 2, got {dut.result.value}"
    print(f"Test 1b (1->3): PASS (got {dut.result.value})")
    
    # Query 3: 3 to 4
    dut.query_s.value = 3
    dut.query_t.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    # Path 3->1->4: 2|1 = 3
    assert dut.result.value == 3, f"Test 1c failed: expected 3, got {dut.result.value}"
    print(f"Test 1c (3->4): PASS (got {dut.result.value})")
    
    # Test 2: 6-node cycle
    # Edges: (1,2,1), (2,3,2), (3,4,3), (4,5,4), (5,6,5), (6,1,6)
    # Expected: 1-4: 1|2|3=3, 2-5: 2|3|4=7, 3-6: 3|4|5|6|1=7
    
    dut.node_count.value = 6
    dut.edge_count.value = 6
    
    edges2 = [
        (1, 2, 1),
        (2, 3, 2),
        (3, 4, 3),
        (4, 5, 4),
        (5, 6, 5),
        (6, 1, 6),
    ]
    
    for i, (src, dst, w) in enumerate(edges2):
        packed = (src << 12) | (dst << 8) | (w & 0xFF)
        dut.edges[i].value = packed
    
    # Query 1: 1 to 4
    dut.query_s.value = 1
    dut.query_t.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    # 1->2->3->4: 1|2|3 = 3
    assert dut.result.value == 3, f"Test 2a failed: expected 3, got {dut.result.value}"
    print(f"Test 2a (1->4): PASS (got {dut.result.value})")
    
    # Query 2: 2 to 5
    dut.query_s.value = 2
    dut.query_t.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    # 2->3->4->5: 2|3|4 = 7
    assert dut.result.value == 7, f"Test 2b failed: expected 7, got {dut.result.value}"
    print(f"Test 2b (2->5): PASS (got {dut.result.value})")
    
    # Query 3: 3 to 6
    dut.query_s.value = 3
    dut.query_t.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 100, "Timeout waiting for done"
    # 3->4->5->6: 3|4|5 = 7 (not using cycle through 1,2 since OR same)
    assert dut.result.value == 7, f"Test 2c failed: expected 7, got {dut.result.value}"
    print(f"Test 2c (3->6): PASS (got {dut.result.value})")
    
    print("All tests passed!")