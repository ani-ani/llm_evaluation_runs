import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random
import itertools

@cocotb.test()
async def test_snack(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.start.value = 0
    
    # Test case 1: Sample Input 1 (scaled)
    # Adjacency matrix for 4-node graph:
    # 1->2, 1->3, 2->4, 3->4
    adj1 = [
        0b00001100,  # Area 1 (index 0): edges to 2(1<<2) and 3(1<<3)
        0b00000000,  # Area 2 (index 1)
        0b00000100,  # Area 3 (index 2)
        0b00000000,  # etc...
        0,0,0,0,0  # Pad to 8x8
    ]
    query1 = {'k':1, 'a':1, 'targets':[3]}  # Area 4 in 0-index =3
    
    # Test case 2: Sample Input 2 (scaled)
    adj2 = [
        # Adjacency matrix for 8-node graph with given edges
        # 1->2, 2->3, 1->3, 3->6, 6->8, 2->4, 2->5, 4->7, 5->7, 7->8
        (1<<1)|(1<<2),  # Area0:1->2,3
        (1<<2)|(1<<3)|(1<<4),  # Area1:2->3,4,5
        0,
        (1<<5),          # Area3:4->7 (index5)
        (1<<5),          # Area4:5->7
        (1<<6),          # Area5:6->8 (index7)
        (1<<7),          # Area6:7->8
        0,
    ]
    query2 = {'k':2, 'a':3, 'targets':[4-1,5-1,6-1]}  # Areas 4,5,6
    
    test_cases = [
        (adj1, 1, 1, [3], 2),
        (adj1, 2, 1, [3], 0),
        (adj2, 2, 3, [3,4,5], 0)  # Expected output matches sample 2 first query
    ]
    passed = 0
    
    for (adj, k_val, a_val, targets, expected) in test_cases:
        # Load adjacency matrix
        for i in range(8):
            dut.adjacency[i].value = adj[i] if i < len(adj) else 0
        
        # Load query parameters
        dut.k.value = k_val
        dut.a.value = a_val
        for i in range(8):
            dut.targets[i].value = targets[i] if i < a_val else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.count.value) == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
