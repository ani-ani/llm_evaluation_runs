import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

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
# MODULAR INVERSE FOR PRIME MODULUS
# ============================================================================

MOD = 1000000007

def mod_pow(base, exp, mod):
    result = 1
    base = base % mod
    while exp > 0:
        if exp % 2 == 1:
            result = (result * base) % mod
        exp = exp >> 1
        base = (base * base) % mod
    return result

def mod_inv(a, mod=MOD):
    # Fermat's little theorem: a^{mod-2} mod mod
    return mod_pow(a, mod-2, mod)

# ============================================================================
# PROBABILITY COMPUTATION (REFERENCE)
# ============================================================================

def compute_probability(n, b_list, p_list):
    """
    Compute probability in software for verification.
    This is a reference implementation using the polynomial DP.
    For small n (<=8) we can compute exactly.
    """
    MOD = 1000000007
    
    # Convert parent indices to 0-based, with -1 for root
    parent = [-1] * n
    children = [[] for _ in range(n)]
    for i in range(n):
        p = p_list[i]
        if p != 0:
            parent[i] = p-1
            children[p-1].append(i)
        else:
            parent[i] = -1
    
    # Precompute polynomial for each node.
    # Represent polynomial as list of coefficients, degree up to n.
    poly = [None] * n
    
    # Process nodes in reverse order (assuming nodes numbered in order, but need topological).
    # We'll use DFS to process leaves first.
    order = []
    visited = [False] * n
    def dfs(u):
        visited[u] = True
        for v in children[u]:
            if not visited[v]:
                dfs(v)
        order.append(u)
    dfs(0)  # root is node 0
    
    # Now process in reverse order (children before parent)
    for u in reversed(order):
        if len(children[u]) == 0:
            # Leaf: f_u(x) = 1
            poly[u] = [1] + [0]*n
        else:
            # Start with polynomial 1
            current = [1] + [0]*n
            # Multiply by each child's g(x)
            for v in children[u]:
                # Compute g_v(x) = ∫_x^{b_v} f_v(y) dy
                f_v = poly[v]
                b_v = b_list[v]
                # Compute constant term C = sum_k a_k * b_v^{k+1} * inv(k+1)
                C = 0
                deg = 0
                for k in range(n+1):
                    if f_v[k] != 0:
                        deg = max(deg, k)
                        term = f_v[k] * mod_pow(b_v % MOD, k+1, MOD) % MOD
                        term = term * mod_inv(k+1, MOD) % MOD
                        C = (C + term) % MOD
                # Build g polynomial: constant C, and -a_{k}/(k+1) for x^{k+1}
                g = [0]*(n+1)
                g[0] = C
                for k in range(deg+1):
                    if f_v[k] != 0:
                        coeff = (-f_v[k] * mod_inv(k+1, MOD)) % MOD
                        if k+1 <= n:
                            g[k+1] = coeff
                # Multiply current * g
                new_current = [0]*(n+1)
                for i in range(n+1):
                    for j in range(n+1):
                        if i+j <= n:
                            new_current[i+j] = (new_current[i+j] + current[i] * g[j]) % MOD
                current = new_current
            # Multiply by product of 1/b_v for each child
            inv_prod = 1
            for v in children[u]:
                inv_prod = inv_prod * mod_inv(b_list[v] % MOD, MOD) % MOD
            for i in range(n+1):
                current[i] = current[i] * inv_prod % MOD
            poly[u] = current
    
    # Now compute result for root
    f_root = poly[0]
    b_root = b_list[0]
    integral = 0
    for k in range(n+1):
        if f_root[k] != 0:
            term = f_root[k] * mod_pow(b_root % MOD, k+1, MOD) % MOD
            term = term * mod_inv(k+1, MOD) % MOD
            integral = (integral + term) % MOD
    result = integral * mod_inv(b_root % MOD, MOD) % MOD
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_heap_probability(dut):
    """Test the HeapProbability module with sample inputs."""
    
    # Configuration
    DATA_WIDTH = 32
    MAX_N = 8
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        # n=2, both b=1e9, expected output 500000004
        {
            'n': 2,
            'b': [1000000000, 1000000000],
            'p': [0, 1],  # node1 root, node2 parent=1
            'expected': 500000004,
            'description': 'Two nodes, equal b, parent-child'
        },
        # n=5, from second example
        {
            'n': 5,
            'b': [2, 2, 1, 2, 2],
            'p': [3, 3, 0, 3, 3],  # node3 is root? Wait input: node1 p=3, node2 p=3, node3 p=0, node4 p=3, node5 p=3
            'expected': 87500001,
            'description': 'Five nodes with given tree'
        }
    ]
    
    for idx, tc in enumerate(test_cases):
        n = tc['n']
        b = tc['b']
        p = tc['p']
        expected = tc['expected']
        desc = tc['description']
        
        cocotb.log.info(f"\nTest {idx+1}: {desc}")
        cocotb.log.info(f"  n={n}, b={b}, p={p}")
        
        # Write inputs to DUT
        dut.n.value = n
        
        # Write b values to individual ports b0..b7
        for i in range(MAX_N):
            if i < n:
                val = b[i]
            else:
                val = 0
            if has_signal(dut, f'b{i}'):
                getattr(dut, f'b{i}').value = val
            else:
                raise TestFailure(f"Missing port b{i}")
        
        # Write parent indices to p0..p7
        # Convert to module format: 0..6 for parent, 255 for root
        for i in range(MAX_N):
            if i < n:
                if p[i] == 0:
                    p_val = 255  # root indicator
                else:
                    p_val = p[i] - 1  # convert to 0-based parent index
            else:
                p_val = 255
            if has_signal(dut, f'p{i}'):
                getattr(dut, f'p{i}').value = p_val
            else:
                raise TestFailure(f"Missing port p{i}")
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=10000)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {idx+1} failed: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"All {len(test_cases)} tests passed")

# Additional test for reference implementation
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reference_probability(dut):
    """Test the reference implementation in Python."""
    test_cases = [
        ([1000000000, 1000000000], [0, 1], 500000004),
        ([2, 2, 1, 2, 2], [3, 3, 0, 3, 3], 87500001),
    ]
    for i, (b, p, expected) in enumerate(test_cases):
        n = len(b)
        computed = compute_probability(n, b, p)
        cocotb.log.info(f"Reference test {i+1}: computed={computed}, expected={expected}")
        if computed != expected:
            raise TestFailure(f"Reference test {i+1} failed")
