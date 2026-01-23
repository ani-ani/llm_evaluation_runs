import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_adjacency_matrix(adjacency_list, num_nodes):
    """Convert adjacency list to adjacency matrix packed format."""
    # adjacency_list is list of lists, each inner list is neighbors of a node
    # We'll pack each row into a 16-bit integer
    matrix = [0] * 16
    for i in range(num_nodes):
        row = 0
        for neighbor in adjacency_list[i]:
            if neighbor < 16:  # Only support up to 16 nodes
                row |= (1 << neighbor)
        matrix[i] = row
    return matrix

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def write_adjacency(dut, adjacency_matrix):
    """Write adjacency matrix to the DUT."""
    for i in range(16):
        if has_signal(dut, f'adjacency_{i}'):
            getattr(dut, f'adjacency_{i}').value = adjacency_matrix[i]
        else:
            # Try indexed array
            try:
                dut.adjacency[i].value = adjacency_matrix[i]
            except:
                raise TestFailure("Cannot access adjacency matrix")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
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
# TEST CASES
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_resource_claim(dut):
    """Test the resource claim module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (description, n, iron_count, coal_count, iron_nodes, coal_nodes, adjacency_list, expected_result, expected_impossible)
    test_cases = [
        (
            "Sample 1: 3 nodes, connected path 1->2->3, iron at 2, coal at 3",
            3, 1, 1,
            [1, 0, 0, 0],  # iron at node 1 (index 1)
            [2, 0, 0, 0],  # coal at node 2 (index 2)
            [[1], [2], [0]],  # adjacency: 0->1, 1->2, 2->0
            2, False
        ),
        (
            "Sample 2: 3 nodes, disconnected",
            3, 1, 1,
            [1, 0, 0, 0],
            [2, 0, 0, 0],
            [[1], [0], [1]],  # 0->1, 1->0, 2->1 (no path from 0 to 2)
            0, True
        ),
        (
            "4 nodes, branching paths",
            4, 1, 1,
            [1, 0, 0, 0],  # iron at node 1
            [3, 0, 0, 0],  # coal at node 3
            [[1, 2], [3], [3], []],  # 0->1,2; 1->3; 2->3
            3, False  # 0->1->3 (2 steps) + 0->2->3 (2 steps), but we only need one path to each
        ),
        (
            "4 nodes, shared prefix",
            4, 1, 1,
            [2, 0, 0, 0],  # iron at node 2
            [3, 0, 0, 0],  # coal at node 3
            [[1], [2, 3], [], []],  # 0->1; 1->2,3
            3, False  # 0->1->2 (iron) and 0->1->3 (coal) = 2+2-1=3 settlers
        ),
        (
            "Simple 2 node case",
            2, 1, 1,
            [1, 0, 0, 0],  # iron at node 1
            [1, 0, 0, 0],  # coal at node 1 - but problem says no cell has both
            [[1], [0]],
            0, True  # Should be impossible since same cell has both, but our scaling prevents this
        ),
        (
            "5 nodes, complex paths",
            5, 1, 1,
            [1, 0, 0, 0],  # iron at node 1
            [4, 0, 0, 0],  # coal at node 4
            [[1, 2], [3], [3, 4], [4], []],  # Multiple paths
            4, False  # 0->1->3->4 (iron path) or 0->2->4 (coal path)
        ),
        (
            "6 nodes, iron and coal in different branches",
            6, 1, 1,
            [2, 0, 0, 0],  # iron at node 2
            [5, 0, 0, 0],  # coal at node 5
            [[1, 3], [2], [], [4], [5], []],  # 0->1->2 (iron), 0->3->4->5 (coal)
            5, False  # 1+3 settlers = 4, but need to count shared path 0->1 and 0->3 separately? Actually 0->1->2 (2) + 0->3->4->5 (3) = 5
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (desc, n, iron_cnt, coal_cnt, iron_nodes, coal_nodes, adjacency_list, expected, exp_impossible) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        
        try:
            # Write configuration
            dut.node_count.value = n
            dut.iron_count.value = iron_cnt
            dut.coal_count.value = coal_cnt
            
            # Write resource arrays
            for i in range(4):
                if has_signal(dut, f'iron_nodes_{i}'):
                    getattr(dut, f'iron_nodes_{i}').value = iron_nodes[i]
                else:
                    dut.iron_nodes[i].value = iron_nodes[i]
                
                if has_signal(dut, f'coal_nodes_{i}'):
                    getattr(dut, f'coal_nodes_{i}').value = coal_nodes[i]
                else:
                    dut.coal_nodes[i].value = coal_nodes[i]
            
            # Write adjacency matrix
            adjacency_matrix = pack_adjacency_matrix(adjacency_list, n)
            await write_adjacency(dut, adjacency_matrix)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut, max_cycles=500)
            
            # Read results
            result_val = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            impossible_val = int(dut.impossible.value) if is_value_defined(dut.impossible.value) else 0
            
            # Verify
            if exp_impossible:
                if impossible_val != 1:
                    raise TestFailure(f"Expected impossible=1, got {impossible_val}")
                cocotb.log.info(f"  PASS: Correctly reported impossible")
            else:
                if impossible_val == 1:
                    raise TestFailure(f"Expected possible, but got impossible")
                if result_val != expected:
                    raise TestFailure(f"Expected {expected}, got {result_val}")
                cocotb.log.info(f"  PASS: result = {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
