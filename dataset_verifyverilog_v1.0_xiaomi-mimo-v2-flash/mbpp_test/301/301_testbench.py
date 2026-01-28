import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_NODES, CLK_NS, MAX_CYCLES = 8, 16, 10, 500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'tree_loaded'): dut.tree_loaded.value = 0
    if has_signal(dut, 'load_valid'): dut.load_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_tree(dut, tree_dict):
    """Load tree from dictionary: {parent: [children]}"""
    # Clear previous loads
    dut.load_valid.value = 0
    dut.tree_loaded.value = 0
    await RisingEdge(dut.clk)
    
    # Load each parent-child pair
    loaded_pairs = []
    for parent, children in tree_dict.items():
        if not isinstance(children, list):
            children = [children] if children is not None else []
        for child in children:
            if child is not None:
                dut.load_addr.value = len(loaded_pairs) % MAX_NODES
                dut.load_parent.value = clamp_to_width(parent, 4)
                dut.load_child.value = clamp_to_width(child, 4)
                dut.load_valid.value = 1
                await RisingEdge(dut.clk)
                loaded_pairs.append((parent, child))
    
    dut.load_valid.value = 0
    # Indicate tree is loaded
    dut.tree_loaded.value = 1
    await RisingEdge(dut.clk)
    dut.tree_loaded.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_dict_depth(dut):
    # Check required signals
    required = ['clk', 'rst_n', 'start', 'tree_loaded', 'done', 'result']
    for sig in required:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing signal: {sig}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases adapted from Python problem
    test_cases = [
        # (tree_dict, expected_depth, description)
        ({'a': 1, 'b': {'c': {'d': {}}}}, 4, "Deeply nested dict"),
        ({'a': 1, 'b': {'c': 'python'}}, 2, "Shallow dict"),
        ({1: 'Sun', 2: {3: {4: 'Mon'}}}, 3, "Integer keys, depth 3"),
        ({'root': {'child1': 'leaf', 'child2': {'grandchild': 'deep'}}}, 3, "Binary tree"),
        ({'x': 'y'}, 1, "Simple pair"),
        ({'a': {'b': {'c': {'d': {'e': {'f': 'g'}}}}}}, 6, "Edge case depth 6"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tree_dict, expected_depth, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Load the tree structure
            await load_tree(dut, tree_dict)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            
            # Check error flag
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    raise TestFailure("Error flag set for valid tree")
            
            if result != expected_depth:
                raise TestFailure(f"Expected depth {expected_depth}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Depth = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_error_conditions(dut):
    """Test error handling for invalid tree structures"""
    
    if not has_signal(dut, 'error'):
        cocotb.log.info("Skipping error test (no error signal)")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case: Self-loop (invalid)
    dut.load_addr.value = 0
    dut.load_parent.value = 0
    dut.load_child.value = 0  # Self-loop
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    dut.tree_loaded.value = 1
    await RisingEdge(dut.clk)
    dut.tree_loaded.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut, MAX_CYCLES)
    
    if is_value_defined(dut.error.value) and int(dut.error.value) != 1:
        cocotb.log.error("Self-loop should trigger error")
    else:
        cocotb.log.info("  PASS: Self-loop error detected")
    
    await reset_dut(dut)
    
    # Test case: Multiple roots (invalid - two nodes with no parent)
    dut.load_addr.value = 0
    dut.load_parent.value = 0
    dut.load_child.value = 1
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_addr.value = 1
    dut.load_parent.value = 2
    dut.load_child.value = 3  # Node 2 has no parent in tree
    dut.load_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    dut.tree_loaded.value = 1
    await RisingEdge(dut.clk)
    dut.tree_loaded.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut, MAX_CYCLES)
    
    if is_value_defined(dut.error.value) and int(dut.error.value) != 1:
        cocotb.log.error("Multiple roots should trigger error")
    else:
        cocotb.log.info("  PASS: Multiple roots error detected")
