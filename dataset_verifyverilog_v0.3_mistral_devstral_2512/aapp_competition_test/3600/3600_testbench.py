import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Additional helper for adjacency matrix
def compute_adjacency_matrix(adj_lists, n):
    """Convert adjacency lists (1-indexed) to adjacency matrix (0-indexed) flattened."""
    matrix = 0
    for i in range(n):
        for neighbor in adj_lists[i]:
            j = neighbor - 1
            if 0 <= j < n:
                matrix |= (1 << (i*8 + j))
                matrix |= (1 << (j*8 + i))
    return matrix

def compute_expected(adj_lists, n, k):
    """Compute whether independent set of size k exists."""
    max_size = 0
    for mask in range(1 << n):
        independent = True
        for i in range(n):
            if (mask >> i) & 1:
                for neighbor in adj_lists[i]:
                    j = neighbor - 1
                    if 0 <= j < n and (mask >> j) & 1:
                        independent = False
                        break
                if not independent:
                    break
        if independent:
            size = bin(mask).count('1')
            if size > max_size:
                max_size = size
    return max_size >= k

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_drone_placement(dut):
    """Test the DronePlacement module."""
    
    is_combinational = not has_signal(dut, 'clk')
    
    # Define test cases
    # Test case 1: example 1
    n1 = 7
    adj_lists1 = [
        [2,4],
        [1,3,5],
        [2],
        [1,5],
        [2,6,4,7],
        [5,7],
        [6,5]
    ]
    adj_lists1 = [list(set(lst)) for lst in adj_lists1]
    k1 = 4
    expected1 = compute_expected(adj_lists1, n1, k1)
    
    # Test case 2: example 2
    n2 = 8
    adj_lists2 = [
        [2,4],
        [1,3,5],
        [2],
        [1,5],
        [2,6,4,7],
        [5,8],
        [8,5],
        [7,6]
    ]
    adj_lists2 = [list(set(lst)) for lst in adj_lists2]
    k2 = 4
    expected2 = compute_expected(adj_lists2, n2, k2)
    
    # Additional test
    n3 = 4
    adj_lists3 = [
        [2],
        [1,3],
        [2,4],
        [3]
    ]
    k3 = 2
    expected3 = compute_expected(adj_lists3, n3, k3)
    
    test_cases = [
        (n1, adj_lists1, k1, expected1, "Example 1 - 7 nodes, k=4"),
        (n2, adj_lists2, k2, expected2, "Example 2 - 8 nodes, k=4"),
        (n3, adj_lists3, k3, expected3, "Linear graph - 4 nodes, k=2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, adj_lists, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        adj_matrix = compute_adjacency_matrix(adj_lists, n)
        
        # Set inputs
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'k'):
            dut.k.value = k
        if has_signal(dut, 'adj'):
            dut.adj.value = adj_matrix
        
        # Wait for propagation
        if is_combinational:
            await Timer(100, units='ns')
        else:
            await Timer(100, units='ns')
        
        # Read output
        if not has_signal(dut, 'possible'):
            raise TestFailure("Output signal 'possible' not found")
        
        if not is_value_defined(dut.possible.value):
            raise TestFailure("Output 'possible' is undefined (X/Z)")
        
        result = int(dut.possible.value)
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: possible = {result}")
        passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
