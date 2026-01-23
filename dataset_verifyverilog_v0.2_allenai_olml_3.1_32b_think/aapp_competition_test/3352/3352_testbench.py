import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

# Helper to simulate the DUT logic
def calculate_magic_color(flat_tree, start, end, num_colors):
    counts = {}
    for i in range(start, end):
        color = flat_tree[i]
        if color != 0:
            counts[color] = counts.get(color, 0) + 1
    magical = 0
    for color in range(1, num_colors + 1):
        if counts.get(color, 0) % 2 == 1:
            magical += 1
    return magical

@cocotb.test()
async def test_magic_color_counter(dut):
    """Test Magic Color Counter"""
    
    # Initialize flat_tree with zeros
    flat_tree = [0] * 256
    
    # Test Case 1: Sample Input 1 (Reduced scale)
    # Tree: 1->2->3->4->5->6->7->8->9->10
    # Colors: 1,2,3,4,5,6,7,8,9,10
    # Max colors supported is 4, so we map inputs mod 4 + 1
    # Let's assume colors 1-4 are used for this test (just mapping high values)
    # Actual colors: 1,2,3,4,1,2,3,4,1,2
    tree_nodes = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2]
    for i, val in enumerate(tree_nodes):
        flat_tree[i] = val
    
    # Write to DUT
    for i in range(256):
        dut.flat_tree[i] = flat_tree[i]
    
    dut.num_colors.value = 4
    
    # Query 1: Subtree of node 1 (indices 0 to 10)
    # Colors: 1x3, 2x3, 3x2, 4x2. All odd counts? No. 1 and 2 are odd (3 times). Count=2.
    dut.query_start_idx.value = 0
    dut.query_end_idx.value = 10
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 0, 10, 4)
    assert dut.magical_count.value == expected, f"Test 1 failed: expected {expected}, got {dut.magical_count.value}"
    
    # Query 2: Subtree of node 4 (indices 3 to 10)
    # Nodes: 4,1,2,3,4,1,2
    # Colors: 4x2, 1x2, 2x2, 3x1. Only 3 is odd. Count=1.
    dut.query_start_idx.value = 3
    dut.query_end_idx.value = 10
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 3, 10, 4)
    assert dut.magical_count.value == expected, f"Test 2 failed: expected {expected}, got {dut.magical_count.value}"

    # Test Case 2: Full tree with 16 nodes, 4 colors
    # Generate random tree structure (linear for simplicity)
    flat_tree = [0] * 256
    for i in range(16):
        flat_tree[i] = (i % 4) + 1  # Cycle colors 1-4
    
    for i in range(256):
        dut.flat_tree[i] = flat_tree[i]
    
    # Query full range
    dut.query_start_idx.value = 0
    dut.query_end_idx.value = 16
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 0, 16, 4)
    assert dut.magical_count.value == expected, f"Test 3 failed: expected {expected}, got {dut.magical_count.value}"

    # Query partial range (1 to 8)
    dut.query_start_idx.value = 1
    dut.query_end_idx.value = 8
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 1, 8, 4)
    assert dut.magical_count.value == expected, f"Test 4 failed: expected {expected}, got {dut.magical_count.value}"

    # Edge case: All same color
    flat_tree = [1] * 10 + [0] * 246
    for i in range(256):
        dut.flat_tree[i] = flat_tree[i]
    dut.query_start_idx.value = 0
    dut.query_end_idx.value = 10
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 0, 10, 4)
    assert dut.magical_count.value == expected, f"Test 5 failed: expected {expected}, got {dut.magical_count.value}"

    # Edge case: Empty range
    dut.query_start_idx.value = 5
    dut.query_end_idx.value = 5
    await Timer(10, units='ns')
    expected = calculate_magic_color(flat_tree, 5, 5, 4)
    assert dut.magical_count.value == expected, f"Test 6 failed: expected {expected}, got {dut.magical_count.value}"
    
    print("All tests passed!")
