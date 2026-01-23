import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def tree_to_repr(d):
    """Convert nested dict to tree representation for Verilog"""
    nodes = []
    parent_mask = 0
    parent_maps = [0] * 8
    
    def traverse(d, parent_idx):
        node_idx = len(nodes)
        nodes.append(d)
        if parent_idx is not None:
            parent_maps[parent_idx] |= (1 << node_idx)
        if isinstance(d, dict):
            parent_mask |= (1 << node_idx)
            for k, v in d.items():
                traverse(v, node_idx)
    
    traverse(d, None)
    return nodes, parent_mask, parent_maps

def get_expected_depth(d):
    """Calculate expected depth of nested dict"""
    if isinstance(d, dict):
        if not d:
            return 1
        return 1 + max(get_expected_depth(v) for v in d.values())
    return 0

@cocotb.test()
async def test_dict_depth(dut):
    """Test dictionary depth calculation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    test_cases = [
        ({'a':1, 'b': {'c': {'d': {}}}}, "Test 1: Deep nesting"),
        ({'a':1, 'b': {'c':'python'}}, "Test 2: Two levels"),
        ({1: 'Sun', 2: {3: {4:'Mon'}}}, "Test 3: Different structure"),
        ({}, "Test 4: Empty dict"),
        ({'a': 1}, "Test 5: Single level"),
        ({'a': {'b': {'c': 1}}}, "Test 6: Chain with value"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_dict, desc) in enumerate(test_cases):
        print(f"
Test {i+1}: {desc}")
        print(f"Input dict: {test_dict}")
        
        # Convert to tree representation
        nodes, parent_mask, parent_maps = tree_to_repr(test_dict)
        expected = get_expected_depth(test_dict)
        
        print(f"Nodes: {len(nodes)}, Expected depth: {expected}")
        print(f"Parent mask: {bin(parent_mask)}, Maps: {[bin(m) for m in parent_maps]}")
        
        # Set inputs
        dut.num_nodes.value = len(nodes)
        dut.parent_mask.value = parent_mask
        dut.parent_map_0.value = parent_maps[0]
        dut.parent_map_1.value = parent_maps[1]
        dut.parent_map_2.value = parent_maps[2]
        dut.parent_map_3.value = parent_maps[3]
        dut.parent_map_4.value = parent_maps[4]
        dut.parent_map_5.value = parent_maps[5]
        dut.parent_map_6.value = parent_maps[6]
        dut.parent_map_7.value = parent_maps[7]
        
        await Timer(5, units='ns')
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAILED: Timeout waiting for done signal")
            continue
        
        # Get result
        result = int(dut.depth.value)
        print(f"  Result: {result}, Cycles: {cycles}")
        
        if result == expected:
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  FAILED: Expected {expected}, got {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await Timer(10, units='ns')
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"

@cocotb.test()
async def test_dict_depth_edge_cases(dut):
    """Test edge cases for dictionary depth"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Edge case: Very deep single chain (8 nodes)
    print("
Edge case: Maximum depth chain (8 nodes)")
    # Node 0->1->2->3->4->5->6->7
    dut.num_nodes.value = 8
    dut.parent_mask.value = 0b01111111  # nodes 0-6 have children
    dut.parent_map_0.value = 0x02  # 0->1
    dut.parent_map_1.value = 0x04  # 1->2
    dut.parent_map_2.value = 0x08  # 2->3
    dut.parent_map_3.value = 0x10  # 3->4
    dut.parent_map_4.value = 0x20  # 4->5
    dut.parent_map_5.value = 0x40  # 5->6
    dut.parent_map_6.value = 0x80  # 6->7
    dut.parent_map_7.value = 0x00
    
    await Timer(5, units='ns')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 50
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    result = int(dut.depth.value)
    print(f"Result: {result} (expected 8)")
    assert result == 8, f"Expected 8, got {result}"
    print("PASSED")
    
    # Edge case: Multiple branches
    print("
Edge case: Multiple branches")
    # Root (0) has children 1,2; Node 1 has child 3; Node 2 has child 4
    # Depth should be 3 (0->1->3 or 0->2->4)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    dut.num_nodes.value = 5
    dut.parent_mask.value = 0b000111  # nodes 0,1,2 have children
    dut.parent_map_0.value = 0x06  # 0->1, 0->2
    dut.parent_map_1.value = 0x08  # 1->3
    dut.parent_map_2.value = 0x10  # 2->4
    dut.parent_map_3.value = 0x00
    dut.parent_map_4.value = 0x00
    dut.parent_map_5.value = 0x00
    dut.parent_map_6.value = 0x00
    dut.parent_map_7.value = 0x00
    
    await Timer(5, units='ns')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    result = int(dut.depth.value)
    print(f"Result: {result} (expected 3)")
    assert result == 3, f"Expected 3, got {result}"
    print("PASSED")
    
    print("
All edge case tests passed!")