import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
N_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
MAX_NODES = 32767

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONSTRAINT CHECKER
# ============================================================================

def verify_tree_constraints(N, preorder):
    """Verify that the preorder traversal satisfies the tree constraints."""
    M = (1 << N) - 1
    if len(preorder) != M:
        return False, f"Expected {M} nodes, got {len(preorder)}"
    
    if sorted(preorder) != list(range(1, M+1)):
        return False, "Not a permutation of 1..M"
    
    # Build tree from preorder
    tree = {}
    def build_tree(idx, level):
        if idx >= M:
            return None, idx
        root = preorder[idx]
        tree[idx] = {'value': root, 'level': level, 'left': None, 'right': None}
        idx += 1
        if idx < M:
            tree[idx]['left'], idx = build_tree(idx, level+1)
        if idx < M:
            tree[idx]['right'], idx = build_tree(idx, level+1)
        return tree[idx-1], idx
    
    root, _ = build_tree(0, 0)
    
    def check_node(node):
        if node is None:
            return True, 0
        left = node['left']
        right = node['right']
        
        if left is None and right is None:
            return True, node['value']
        
        if left is None or right is None:
            return False, 0
        
        ok_left, sum_left = check_node(left)
        ok_right, sum_right = check_node(right)
        if not ok_left or not ok_right:
            return False, 0
        
        total_sum = node['value'] + sum_left + sum_right
        diff = abs(sum_left - sum_right)
        expected_diff = 1 << node['level']
        
        if diff != expected_diff:
            return False, 0
        
        return True, total_sum
    
    ok, _ = check_node(root)
    return ok, "Constraints violated"

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_binary_tree_generator(dut):
    """Test the binary tree generator module."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst_n = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_valid = has_signal(dut, 'valid')
    has_N = has_signal(dut, 'N')
    has_data = has_signal(dut, 'preorder_data')
    has_index = has_signal(dut, 'preorder_index')
    
    if not all([has_clk, has_rst_n, has_start, has_done, has_valid, has_N, has_data]):
        cocotb.log.error("Missing required signals")
        raise TestFailure("Module missing required signals")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, expected_preorder)
    test_cases = [
        (2, [1, 2, 3]),
        (3, [1, 3, 4, 6, 2, 5, 7]),
    ]
    
    for test_N, expected in test_cases:
        cocotb.log.info(f"Testing N={test_N}")
        
        # Start computation
        dut.N.value = test_N
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Collect preorder output
        preorder = []
        max_nodes = (1 << test_N) - 1
        
        for i in range(max_nodes):
            # Wait for valid data
            timeout = 0
            while not (is_value_defined(dut.valid.value) and int(dut.valid.value) == 1):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 100:
                    raise TestFailure(f"Valid signal not asserted for node {i}")
            
            # Read data
            if is_value_defined(dut.preorder_data.value):
                preorder.append(int(dut.preorder_data.value))
            else:
                raise TestFailure(f"Undefined data at node {i}")
            
            await RisingEdge(dut.clk)
        
        # Verify constraints
        ok, msg = verify_tree_constraints(test_N, preorder)
        if not ok:
            raise TestFailure(f"N={test_N}: {msg}. Got: {preorder}")
        
        # Also check against expected if provided
        if preorder != expected:
            cocotb.log.warning(f"N={test_N}: Got {preorder}, expected {expected}")
            # But still pass if constraints are satisfied
            cocotb.log.info(f"N={test_N}: Constraints satisfied, alternative solution found")
        else:
            cocotb.log.info(f"N={test_N}: PASS - matches expected output")
    
    cocotb.log.info("All tests completed successfully")
