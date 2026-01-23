import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def float_to_q1616(f):
    return int(f * 65536)

def q1616_to_float(q):
    return q / 65536.0

@cocotb.test()
async def test_lemonade_trade(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Simple 3-node graph (Sample 1)
    # 3
    # blue pink 1.0
    # red pink 1.5
    # blue red 1.0
    # Expected: 1.5
    # Path: pink -> red (1.5) -> blue (1.0) = 1.5
    # Nodes: pink=0, red=1, blue=2
    dut.num_nodes.value = 3
    dut.num_edges.value = 3
    dut.pink_idx.value = 0
    dut.blue_idx.value = 2
    
    # Edge 0: blue pink 1.0 -> start=pink(0), end=blue(2), rate=1.0
    dut.edge_start[0].value = 0
    dut.edge_end[0].value = 2
    dut.edge_rate[0].value = float_to_q1616(1.0)
    
    # Edge 1: red pink 1.5 -> start=pink(0), end=red(1), rate=1.5
    dut.edge_start[1].value = 0
    dut.edge_end[1].value = 1
    dut.edge_rate[1].value = float_to_q1616(1.5)
    
    # Edge 2: blue red 1.0 -> start=red(1), end=blue(2), rate=1.0
    dut.edge_start[2].value = 1
    dut.edge_end[2].value = 2
    dut.edge_rate[2].value = float_to_q1616(1.0)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (max 100 cycles)
    for _ in range(110):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test Case 1: Done signal did not go high")
    
    result = q1616_to_float(int(dut.max_blue.value))
    print(f"Test Case 1 Result: {result}")
    assert abs(result - 1.5) < 0.0001, f"Expected 1.5, got {result}"

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Impossible path (Sample 2)
    # 2
    # blue red 1.0
    # red pink 1.5
    # Expected: 0.0
    # Path: pink -> red (1.5), but no red -> blue (only blue -> red)
    dut.num_nodes.value = 3 # pink, red, blue
    dut.num_edges.value = 2
    dut.pink_idx.value = 0
    dut.blue_idx.value = 2
    
    # Edge 0: blue red 1.0 -> start=red(1), end=blue(2)
    dut.edge_start[0].value = 1
    dut.edge_end[0].value = 2
    dut.edge_rate[0].value = float_to_q1616(1.0)
    
    # Edge 1: red pink 1.5 -> start=pink(0), end=red(1)
    dut.edge_start[1].value = 0
    dut.edge_end[1].value = 1
    dut.edge_rate[1].value = float_to_q1616(1.5)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(110):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result = q1616_to_float(int(dut.max_blue.value))
    print(f"Test Case 2 Result: {result}")
    assert abs(result - 0.0) < 0.0001, f"Expected 0.0, got {result}"

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Capping at 10.0 (Sample 3)
    # 4
    # orange pink 1.9
    # yellow orange 1.9
    # green yellow 1.9
    # blue green 1.9
    # Expected: 10.0
    # Product = 1.9^4 = 13.0321 > 10.0
    dut.num_nodes.value = 5 # pink, orange, yellow, green, blue
    dut.num_edges.value = 4
    dut.pink_idx.value = 0
    dut.blue_idx.value = 4
    
    # Edge 0: orange pink 1.9 -> 0->1
    dut.edge_start[0].value = 0
    dut.edge_end[0].value = 1
    dut.edge_rate[0].value = float_to_q1616(1.9)
    
    # Edge 1: yellow orange 1.9 -> 1->2
    dut.edge_start[1].value = 1
    dut.edge_end[1].value = 2
    dut.edge_rate[1].value = float_to_q1616(1.9)
    
    # Edge 2: green yellow 1.9 -> 2->3
    dut.edge_start[2].value = 2
    dut.edge_end[2].value = 3
    dut.edge_rate[2].value = float_to_q1616(1.9)
    
    # Edge 3: blue green 1.9 -> 3->4
    dut.edge_start[3].value = 3
    dut.edge_end[3].value = 4
    dut.edge_rate[3].value = float_to_q1616(1.9)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(110):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result = q1616_to_float(int(dut.max_blue.value))
    print(f"Test Case 3 Result: {result}")
    assert abs(result - 10.0) < 0.0001, f"Expected 10.0, got {result}"

    # Test Case 4: Longer path with rates < 1.0 (Sample 4 adapted)
    # Path: pink->...->blue with rates 1.9 and 0.6
    # 1.9^4 * 0.6^4 = 0.130321 * 0.1296 = 0.0168896
    # Result: 0.0168896 * 1 = 0.0168896 (Wait, sample 4 output is 1.68896)
    # Sample 4 output is 1.68896. Let's check input:
    # 1.9^4 * 0.6^4 = (1.9*0.6)^4 = 1.14^4 = 1.68896
    # Correct.
    dut.num_nodes.value = 9 # pink, red, orange, yellow, green, indigo, violet, purple, blue
    dut.num_edges.value = 8
    dut.pink_idx.value = 0
    dut.blue_idx.value = 8
    
    rates = [1.9, 1.9, 1.9, 1.9, 0.6, 0.6, 0.6, 0.6]
    starts = [0, 1, 2, 3, 4, 5, 6, 7] # 0->1->2->3->4->5->6->7->8
    ends =   [1, 2, 3, 4, 5, 6, 7, 8]
    
    for i in range(8):
        dut.edge_start[i].value = starts[i]
        dut.edge_end[i].value = ends[i]
        dut.edge_rate[i].value = float_to_q1616(rates[i])

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(110):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result = q1616_to_float(int(dut.max_blue.value))
    print(f"Test Case 4 Result: {result}")
    assert abs(result - 1.68896) < 0.001, f"Expected 1.68896, got {result}"

    print("All tests passed!")
