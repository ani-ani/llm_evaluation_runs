import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
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

# Brute-force solver for the small tree
def brute_force_max_heap_subset(n, values, parents):
    """
    Compute maximum size of subset satisfying heap property.
    n: number of nodes (<=8)
    values: list of values
    parents: list of parent indices (1-based, 0 for root)
    Returns maximum subset size.
    """
    max_size = 0
    # Enumerate all subsets of nodes (0..n-1)
    for mask in range(1, 1 << n):
        # Check validity
        valid = True
        for i in range(n):
            if (mask >> i) & 1:
                for j in range(n):
                    if i == j:
                        continue
                    if (mask >> j) & 1:
                        # Check if i is ancestor of j
                        # Need to convert to 0-based parents
                        # Build parent array for this subset check
                        # We'll precompute ancestor relationships for the whole tree
                        pass
        # Instead, we will compute ancestor relationships once outside
        pass
    # We'll implement a proper solver below
    # First, build adjacency list for parent pointers (0-based)
    parent0 = [0]*n
    for i in range(n):
        if i == 0:
            parent0[i] = -1  # no parent
        else:
            parent0[i] = parents[i] - 1  # convert to 0-based
    # Precompute ancestor matrix
    anc = [[False]*n for _ in range(n)]
    for j in range(n):
        k = parent0[j]
        while k != -1:
            anc[k][j] = True
            k = parent0[k]
    # Enumerate subsets
    max_size = 0
    for mask in range(1, 1 << n):
        ok = True
        for i in range(n):
            if (mask >> i) & 1:
                for j in range(n):
                    if i == j:
                        continue
                    if (mask >> j) & 1:
                        if anc[i][j] and values[i] <= values[j]:
                            ok = False
                            break
                if not ok:
                    break
        if ok:
            cnt = bin(mask).count('1')
            if cnt > max_size:
                max_size = cnt
    return max_size

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_heap_subset_finder(dut):
    """Test the heap subset finder module."""
    # Configuration
    N = 8
    V_WIDTH = 8
    P_WIDTH = 3
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_mask.value = 0
    for i in range(N):
        getattr(dut, f'v{i}').value = 0
        getattr(dut, f'p{i}').value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, values, parents, expected)
    # We'll use the provided examples but truncate to N=8
    # Example 1: n=5, all values 3, parents 0,1,2,3,4
    # After conversion: values = [3,3,3,3,3], parents = [0,1,2,3,4]
    # We'll add dummy nodes for i=5..7 (value=0, parent=N, valid_mask=0)
    
    test_cases = [
        (5, [3,3,3,3,3], [0,1,2,3,4], 1),
        (5, [4,3,2,1,0], [0,1,2,3,4], 5),
        (6, [3,1,2,3,4,5], [0,1,1,1,1,1], 5),
        (11, [7,8,5,5,4,3,6,6,10,9,11], [0,1,1,2,2,2,3,3,4,4,4], 7),
    ]
    
    for test_idx, (n, vals, pars, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {test_idx+1}: n={n}")
        
        # Prepare inputs
        # Transform parents: root parent = N (8), others = p-1
        p_transformed = [N] * N
        for i in range(n):
            if i == 0:
                p_transformed[i] = N  # root has no parent
            else:
                p_transformed[i] = pars[i] - 1  # convert to 0-based
        
        # Values: extend to N elements
        v_extended = vals + [0] * (N - n)
        # Valid mask: bits 0..n-1 = 1
        valid_mask = (1 << n) - 1
        
        # Assign inputs
        dut.valid_mask.value = valid_mask
        for i in range(N):
            getattr(dut, f'v{i}').value = clamp_to_width(v_extended[i], V_WIDTH)
            getattr(dut, f'p{i}').value = clamp_to_width(p_transformed[i], P_WIDTH)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 100000  # generous timeout
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > max_cycles:
                raise TestFailure(f"Timeout after {max_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        result = int(dut.result.value)
        
        # Compute expected using brute-force
        expected_computed = brute_force_max_heap_subset(n, vals, pars)
        if result != expected_computed:
            raise TestFailure(f"Test {test_idx+1}: expected {expected_computed}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
