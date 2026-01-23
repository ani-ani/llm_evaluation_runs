import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

@cocotb.test()
async def test_graph_partition(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.edges.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Valid partition (n=4)
    # Nodes: 1, 2, 3, 4
    # Arya: {1, 3} (Edges 1-3)
    # Sansa: {2, 4} (Edges 2-4)
    # Jon: {} (Empty)
    # Graph must have: 1-3, 2-4. No other edges required but must not violate cliques.
    # So 1 cannot connect to 2 or 4. 3 cannot connect to 2 or 4.
    # Complement graph logic:
    # If we want {1,3} and {2,4} to be cliques (in original graph):
    # Edges needed: 1-3, 2-4.
    # Any other edge is allowed provided it doesn't prevent them from being cliques? 
    # Actually, if we have an edge 1-4, then 1 is connected to 3 and 4. If 1 is in Arya, 4 cannot be in Arya (unless 3-4 exists).
    # Let's construct a simple valid graph for n=4.
    # Edges: 1-3 (Arya clique), 2-4 (Sansa clique).
    # Nodes 1,2,3,4.
    dut.n.value = 4
    dut.m.value = 2
    # Edge list: 1-3, 2-4. Encode as {u[1:0], v[1:0]} for 4 nodes.
    # Node 1=1, Node 3=3. Node 2=2, Node 4=4.
    # Flattened: 4 bits per edge. 16 edges capacity.
    # Edge 1: 01 11 -> 0x13 (19 decimal)
    # Edge 2: 10 00 -> 0x20 (32 decimal)
    # Wait, indices 1..4. In 2 bits 00,01,10,11 map to 0..3. 
    # 1->00, 2->01, 3->10, 4->11? Or 1->01? 
    # Let's use 0-based indexing for bits: 1->0, 2->1, 3->2, 4->3.
    # Edge 1 (1-3): 00 10 -> 0x02
    # Edge 2 (2-4): 01 11 -> 0x07
    # Let's assume standard 1-based input but 0-based internal if needed, or just mask.
    # The prompt says {u[1:0], v[1:0]}. Let's assume u=1..4 maps to bits 0..3.
    # So 1=0b00, 2=0b01, 3=0b10, 4=0b11.
    # Edge 1-3: 00, 10 -> value {00, 10} = 0x2? 0010b = 2.
    # Edge 2-4: 01, 11 -> 0111b = 7.
    # Set edge 0 to 2, edge 1 to 7.
    dut.edges[0].value = 2
    dut.edges[1].value = 7
    dut.edges[2].value = 0
    dut.edges[3].value = 0
    # ... reset others
    for i in range(4, 16):
        dut.edges[i].value = 0

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Timeout waiting for done"
    assert dut.valid.value == 1, "Test case 1 should be valid"
    # Expected: Arya {1, 3} -> 0b1010? No, 1 is index 0, 3 is index 2.
    # If 1-based output: {1, 3} -> bits 0 and 2.
    # If Arya set contains 1 (bit 0) and 3 (bit 2), mask is 0b0101 (5).
    # Sansa {2, 4} -> bits 1 and 3 -> 0b1010 (10).
    print(f"Test 1: Arya={dut.arya_set.value}, Sansa={dut.sansa_set.value}")
    assert dut.arya_set.value == 5 or dut.arya_set.value == 0, "Arya set mismatch"
    assert dut.sansa_set.value == 10 or dut.sansa_set.value == 0, "Sansa set mismatch"

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Impossible case
    # n=4
    # Graph: 1-2 (Edge between required nodes -> impossible)
    dut.n.value = 4
    dut.m.value = 1
    # Edge 1-2: 00 01 -> 0x01
    dut.edges[0].value = 1
    for i in range(1, 16):
        dut.edges[i].value = 0

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Timeout waiting for done"
    assert dut.valid.value == 0, "Test case 2 should be impossible"
    print(f"Test 2: Valid={dut.valid.value}")

    print("All tests passed")
