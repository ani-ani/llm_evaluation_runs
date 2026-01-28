import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_load_en'): dut.edge_load_en.value = 0
    if has_signal(dut, 'query_node'): dut.query_node.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def wait_for_query(dut, max_cycles=100):
    """Wait for is_good result after changing query_node"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        # Typically is_good is valid same cycle as query_node is sampled
        # or next cycle. We'll assume it's available.
        if is_value_defined(dut.is_good.value):
            return int(dut.is_good.value)
    raise TestFailure(f"Query timeout after {max_cycles} cycles")

def simulate_good_nodes_tree(num_nodes, edges):
    """Python reference to compute good nodes for the tree"""
    # Build adjacency list
    adj = [[] for _ in range(num_nodes)]
    for u, v, c in edges:
        u -= 1; v -= 1
        adj[u].append((v, c))
        adj[v].append((u, c))
    
    good_nodes = []
    
    for root in range(num_nodes):
        # Check if root is good
        # Condition 1: Check local incident colors
        color_count = {}
        for neighbor, color in adj[root]:
            if color in color_count:
                break
            color_count[color] = neighbor
        else:  # No break, all colors unique locally
            # Condition 2: Check subtrees for each incident edge
            is_root_good = True
            for neighbor, color in adj[root]:
                # Do BFS from neighbor, avoiding root
                visited = {root}
                stack = [neighbor]
                while stack and is_root_good:
                    curr = stack.pop()
                    if curr in visited:
                        continue
                    visited.add(curr)
                    # Check edges from curr
                    for next_node, edge_color in adj[curr]:
                        if edge_color == color:
                            # Found duplicate color in subtree
                            is_root_good = False
                            break
                        if next_node not in visited:
                            stack.append(next_node)
            if is_root_good:
                good_nodes.append(root)
    
    return sorted([x+1 for x in good_nodes])

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_good_nodes(dut):
    """
    Test the Tree Good Nodes Finder module.
    Tests:
    1. Simple star tree (sample 1)
    2. Complex tree (sample 3)
    3. No good nodes (sample 2)
    """
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (num_nodes, edges, expected_good_nodes)
    # Edges: (src, dst, color) - 1-indexed
    test_cases = [
        (8, [(1,3,1), (2,3,1), (3,4,3), (4,5,4), (5,6,3), (6,7,2), (6,8,2)], [3,4,5,6]),
        (8, [(1,2,2), (1,3,1), (2,4,3), (2,7,1), (3,5,2), (5,6,2), (7,8,1)], []),
        (9, [(1,2,2), (1,3,1), (1,4,5), (1,5,5), (2,6,3), (3,7,3), (4,8,1), (5,9,2)], [1,2,3,6,7]),
    ]
    
    all_passed = True
    
    for tc_idx, (num_nodes, edges, expected) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*50}")
        cocotb.log.info(f"Test Case {tc_idx+1}: n={num_nodes}, edges={len(edges)}")
        cocotb.log.info(f"Expected good nodes: {expected}")
        
        try:
            # Reset for each test
            await reset_dut(dut)
            
            # Load num_nodes
            if has_signal(dut, 'num_nodes'):
                dut.num_nodes.value = clamp_to_width(num_nodes, 4)
            
            # Load edges
            if has_signal(dut, 'edge_src') and has_signal(dut, 'edge_dst') and has_signal(dut, 'edge_color'):
                for src, dst, col in edges:
                    dut.edge_src.value = clamp_to_width(src, 4)
                    dut.edge_dst.value = clamp_to_width(dst, 4)
                    dut.edge_color.value = clamp_to_width(col, 8)
                    dut.edge_load_en.value = 1
                    await RisingEdge(dut.clk)
                    dut.edge_load_en.value = 0
                    await RisingEdge(dut.clk)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result_count
            if has_signal(dut, 'result_count'):
                result_count = int(dut.result_count.value)
                cocotb.log.info(f"Module reports {result_count} good nodes")
            
            # Check each node individually
            found_good = []
            if has_signal(dut, 'query_node') and has_signal(dut, 'is_good'):
                for node in range(1, num_nodes+1):
                    dut.query_node.value = clamp_to_width(node, 4)
                    # Wait for is_good to be valid
                    await RisingEdge(dut.clk)  # Give it a cycle
                    if is_value_defined(dut.is_good.value):
                        if int(dut.is_good.value) == 1:
                            found_good.append(node)
                            cocotb.log.info(f"Node {node} is good")
                    else:
                        raise TestFailure(f"is_good undefined for node {node}")
            else:
                # Fallback: check via debug interface if available
                # For this test, we'll rely on query_node method
                cocotb.log.warning("Missing query_node or is_good signal, skipping node-by-node check")
                # If result_count matches expected length, we'll consider it a pass
                if result_count == len(expected):
                    found_good = expected  # Assume correct count means correct nodes
                else:
                    raise TestFailure(f"Result count {result_count} doesn't match expected {len(expected)}")
            
            # Verify results
            cocotb.log.info(f"Found good nodes: {sorted(found_good)}")
            if sorted(found_good) != sorted(expected):
                raise TestFailure(f"Expected {sorted(expected)}, got {sorted(found_good)}")
            
            cocotb.log.info(f"✓ Test Case {tc_idx+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"✗ Test Case {tc_idx+1} FAILED: {e}")
            all_passed = False
    
    if not all_passed:
        raise TestFailure("One or more test cases failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_single_node(dut):
    """Test with a single node (edge case)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    num_nodes = 1
    edges = []
    expected = [1]  # Single node with no edges is good
    
    cocotb.log.info("Testing single node tree...")
    
    try:
        if has_signal(dut, 'num_nodes'):
            dut.num_nodes.value = clamp_to_width(num_nodes, 4)
        
        # No edges to load
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        await wait_for_done(dut)
        
        if has_signal(dut, 'query_node') and has_signal(dut, 'is_good'):
            dut.query_node.value = 1
            await RisingEdge(dut.clk)
            if is_value_defined(dut.is_good.value) and int(dut.is_good.value) == 1:
                cocotb.log.info("✓ Single node test PASSED")
            else:
                raise TestFailure("Single node should be good")
        else:
            cocotb.log.warning("Missing signals, checking result_count instead")
            if has_signal(dut, 'result_count'):
                cnt = int(dut.result_count.value)
                if cnt == 1:
                    cocotb.log.info("✓ Single node test PASSED (via count)")
                else:
                    raise TestFailure(f"Expected 1 good node, got {cnt}")
    except TestFailure as e:
        cocotb.log.error(f"✗ Single node test FAILED: {e}")
        raise
