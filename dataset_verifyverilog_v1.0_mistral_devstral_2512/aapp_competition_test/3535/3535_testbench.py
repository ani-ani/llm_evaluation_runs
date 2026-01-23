import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 4
SPIN_WIDTH = 1
MAX_K = 8
RESULT_WIDTH = 32
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

# ============================================================================
# EXPECTED RESULT COMPUTATION (Python)
# ============================================================================

def compute_expected(N, M, K, measurements):
    """
    Compute the number of valid states modulo 1e9+7.
    measurements: list of tuples (y, x, s) where s is 0 for '+', 1 for '-'
    """
    MOD = 10**9 + 7
    # Build union-find with parity
    total_nodes = N + M
    parent = list(range(total_nodes))
    parity = [0] * total_nodes
    inconsistent = False

    def find(node):
        # Returns (root, parity_to_root)
        p = 0
        cur = node
        while parent[cur] != cur:
            p ^= parity[cur]
            cur = parent[cur]
        return cur, p

    def union(u, v, w):
        nonlocal inconsistent
        ru, pu = find(u)
        rv, pv = find(v)
        if ru == rv:
            if (pu ^ pv) != w:
                inconsistent = True
        else:
            # attach ru to rv
            parent[ru] = rv
            parity[ru] = pu ^ pv ^ w

    for y, x, s in measurements:
        u = y
        v = N + x
        w = s
        union(u, v, w)

    if inconsistent:
        return 0

    # Count distinct roots among all nodes
    roots = set()
    for i in range(total_nodes):
        r, _ = find(i)
        roots.add(r)
    C = len(roots)
    # result = 2^(C-1) mod MOD
    result = pow(2, C-1, MOD)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_quantum_chip_solver(dut):
    """Main test function."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases
    # Format: (N, M, K, measurements, description)
    # measurements: list of (y, x, spin_char)
    test_cases = [
        (2, 4, 4, [(0,0,'+'), (0,1,'-'), (0,2,'+'), (0,3,'-')], "Example 1: 2x4 with 4 measurements"),
        (3, 3, 3, [(1,0,'-'), (1,2,'+'), (2,2,'+')], "Example 2: 3x3 with 3 measurements"),
        (1, 1, 0, [], "Minimal grid, no measurements"),
        (2, 2, 1, [(0,0,'+')], "2x2 with one measurement"),
        (2, 2, 2, [(0,0,'+'), (0,1,'-')], "2x2 with two measurements, consistent"),
        (2, 2, 2, [(0,0,'+'), (1,1,'+')], "2x2 with two measurements, may be inconsistent"),
        (3, 4, 5, [(0,0,'+'), (1,1,'-'), (2,2,'+'), (0,3,'-'), (1,2,'+')], "3x4 with 5 measurements"),
        (4, 4, 8, [(0,0,'+'), (0,1,'-'), (0,2,'+'), (0,3,'-'),
                   (1,0,'-'), (1,1,'+'), (1,2,'-'), (1,3,'+')], "4x4 with 8 measurements, all consistent"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, K, measurements, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set N, M, K
            if has_signal(dut, 'N'):
                dut.N.value = N
            if has_signal(dut, 'M'):
                dut.M.value = M
            if has_signal(dut, 'K'):
                dut.K.value = K
            
            # Set measurements (up to MAX_K)
            for idx in range(MAX_K):
                if idx < K:
                    y, x, spin_char = measurements[idx]
                    s = 0 if spin_char == '+' else 1
                else:
                    y, x, s = 0, 0, 0
                
                # Set each port individually
                if has_signal(dut, f'y_{idx}'):
                    getattr(dut, f'y_{idx}').value = y
                if has_signal(dut, f'x_{idx}'):
                    getattr(dut, f'x_{idx}').value = x
                if has_signal(dut, f's_{idx}'):
                    getattr(dut, f's_{idx}').value = s
            
            # Pulse start
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Compute expected
            # Convert measurements to list of (y, x, s) with s as 0/1
            meas_py = [(y, x, 0 if spin == '+' else 1) for (y, x, spin) in measurements]
            expected = compute_expected(N, M, K, meas_py)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")