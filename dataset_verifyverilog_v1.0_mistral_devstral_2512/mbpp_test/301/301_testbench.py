import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TREE CONSTRUCTION HELPER
# ============================================================================

def build_tree_representation(test_dict, root_id=0):
    """
    Convert Python dictionary to adjacency matrix representation.
    Returns: (children_bits, node_is_dict_bits, root_node)
    - children_bits: list of 8 integers, each 8-bit row of adjacency matrix
    - node_is_dict_bits: 8-bit value where bit i=1 if node i is dict
    - root_node: index of root node
    """
    node_id = 0
    children_bits = [0] * 8
    node_is_dict = 0
    
    # Build tree using BFS
    queue = [(root_id, test_dict)]
    visited = {root_id}
    
    while queue and node_id < 8:
        current_id, current_dict = queue.pop(0)
        
        # Mark as dictionary
        if isinstance(current_dict, dict):
            node_is_dict |= (1 << current_id)
            
            # Process children
            for key, value in current_dict.items():
                if node_id + 1 >= 8:
                    break
                
                node_id += 1
                child_id = node_id
                
                # Add edge from parent to child
                children_bits[current_id] |= (1 << child_id)
                
                # If child is dict, add to queue
                if isinstance(value, dict):
                    queue.append((child_id, value))
                else:
                    # Leaf node - not a dict
                    pass
    
    return children_bits, node_is_dict, root_id

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dict_depth(dut):
    """Test dictionary depth calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (dictionary, expected_depth, description)
    test_cases = [
        ({'a':1, 'b': {'c': {'d': {}}}}, 4, "Test 1: Deep nesting with empty dict"),
        ({'a':1, 'b': {'c':'python'}}, 2, "Test 2: Nested dict with value"),
        ({1: 'Sun', 2: {3: {4:'Mon'}}}, 3, "Test 3: Numeric keys with nesting"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_dict, expected_depth, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {test_dict}")
        cocotb.log.info(f"  Expected depth: {expected_depth}")
        
        try:
            # Convert dictionary to hardware representation
            children_bits, node_is_dict, root_node = build_tree_representation(test_dict)
            
            cocotb.log.info(f"  Tree: {len(test_dict)} nodes, root={root_node}")
            cocotb.log.info(f"  node_is_dict=0b{node_is_dict:08b}")
            
            # Write inputs
            dut.root_node.value = root_node
            dut.node_is_dict.value = node_is_dict
            
            # Write adjacency matrix rows
            dut.node_children_0.value = children_bits[0]
            dut.node_children_1.value = children_bits[1]
            dut.node_children_2.value = children_bits[2]
            dut.node_children_3.value = children_bits[3]
            dut.node_children_4.value = children_bits[4]
            dut.node_children_5.value = children_bits[5]
            dut.node_children_6.value = children_bits[6]
            dut.node_children_7.value = children_bits[7]
            
            # Wait for propagation
            await Timer(50, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.depth.value):
                raise TestFailure("Result depth is undefined (X/Z)")
            
            result = int(dut.depth.value)
            
            # Verify
            if result != expected_depth:
                raise TestFailure(f"Expected {expected_depth}, got {result}")
            
            cocotb.log.info(f"  PASS: depth={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")