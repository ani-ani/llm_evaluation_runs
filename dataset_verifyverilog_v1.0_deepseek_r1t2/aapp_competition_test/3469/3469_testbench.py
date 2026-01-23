import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
# ARRAY WRITE/READ HELPERS (RULE B)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling 2D array or individual ports."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling 2D array or individual ports."""
    results = []
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
# SEQUENTIAL HELPERS
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

async def wait_for_done(dut, max_cycles=10000):
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
# AUTOMATON BUILDING (PYTHON SIDE)
# ============================================================================

def build_automaton(g, k):
    """Build Markov chain states and transitions for patterns g and k.
    Returns: (state_list, next_H, next_T, state_index_map)
    state_list: list of (i,j) where i=progress in g, j=progress in k (both 0..len)
    next_H/T: lists of next state codes for each state (0..N-1 or 8/9/10 for absorbing)
    """
    len_g = len(g)
    len_k = len(k)
    # Create all non-absorbing states (i,j) with i<len_g and j<len_k
    state_map = {}
    state_list = []
    idx = 0
    for i in range(len_g + 1):
        for j in range(len_k + 1):
            # Skip absorbing states:
            if (i == len_g and j == len_k) or (i == len_g and j < len_k) or (j == len_k and i < len_g):
                continue
            state_map[(i, j)] = idx
            state_list.append((i, j))
            idx += 1
    N = idx
    next_H = [0] * N
    next_T = [0] * N
    for s, (i, j) in enumerate(state_list):
        for char, trans_list in zip(['H', 'T'], [next_H, next_T]):
            # Compute new i, j after appending char
            new_i = i
            new_j = j
            # Try to extend g
            while new_i > 0 and (g[:new_i] + char) != g[:new_i+1]:
                new_i -= 1
            if new_i < len_g and g[new_i] == char:
                new_i += 1
            # Try to extend k
            while new_j > 0 and (k[:new_j] + char) != k[:new_j+1]:
                new_j -= 1
            if new_j < len_k and k[new_j] == char:
                new_j += 1
            # Determine absorption
            if new_i == len_g and new_j == len_k:
                code = 10   # Draw
            elif new_i == len_g:
                code = 8    # Gon win
            elif new_j == len_k:
                code = 9    # Killua win
            else:
                code = state_map[(new_i, new_j)]
            trans_list[s] = code
    return state_list, next_H, next_T, state_map

def compute_exact_probability(g, k, p_float):
    """Compute exact probability using linear equations (Gauss elimination)."""
    state_list, next_H, next_T, state_map = build_automaton(g, k)
    N = len(state_list)
    if N == 0:
        # No non-absorbing states: the first flip determines outcome
        # Actually this cannot happen because patterns non-empty and at least state (0,0) exists
        return 0.0
    # Build matrix A and vector b: A * x = b
    A = [[0.0] * N for _ in range(N)]
    b = [0.0] * N
    for s in range(N):
        A[s][s] = 1.0
        # H transition
        nxt = next_H[s]
        if nxt == 8:
            b[s] += p_float * 1.0
        elif nxt == 9 or nxt == 10:
            b[s] += p_float * 0.0
        else:
            A[s][nxt] -= p_float
        # T transition
        nxt = next_T[s]
        if nxt == 8:
            b[s] += (1.0 - p_float) * 1.0
        elif nxt == 9 or nxt == 10:
            b[s] += (1.0 - p_float) * 0.0
        else:
            A[s][nxt] -= (1.0 - p_float)
    # Solve linear system using Gaussian elimination
    # Augmented matrix
    for i in range(N):
        A[i].append(b[i])
    for col in range(N):
        # Find pivot
        pivot_row = col
        for row in range(col+1, N):
            if abs(A[row][col]) > abs(A[pivot_row][col]):
                pivot_row = row
        if abs(A[pivot_row][col]) < 1e-12:
            continue
        # Swap
        A[col], A[pivot_row] = A[pivot_row], A[col]
        # Normalize
        factor = A[col][col]
        for j in range(col, N+1):
            A[col][j] /= factor
        # Eliminate
        for row in range(N):
            if row != col:
                factor = A[row][col]
                for j in range(col, N+1):
                    A[row][j] -= factor * A[col][j]
    # Solution is in last column
    x = [A[i][N] for i in range(N)]
    # Initial state is (0,0)
    init_idx = state_map.get((0,0), None)
    if init_idx is None:
        return 0.0
    return x[init_idx]

# ============================================================================
# FIXED-POINT CONVERSION
# ============================================================================

FRAC_BITS = 16

def float_to_fixed(f):
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gon_probability(dut):
    """Test the generic gon probability module."""
    
    # Configuration
    MAX_STATES = 16
    CLK_PERIOD_NS = 10
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases (g, k, p_float)
    # Use the examples from the problem
    test_cases = [
        ("H", "T", 0.5, 0.5),
        ("HH", "TH", 0.5, 0.25),
    ]
    
    # Set constant signals that are not used but must exist
    if has_signal(dut, 'MAX_STATES'):
        dut.MAX_STATES.value = MAX_STATES
    if has_signal(dut, 'STATE_BITS'):
        dut.STATE_BITS.value = 4
    if has_signal(dut, 'ITERATIONS'):
        dut.ITERATIONS.value = 256
    
    passed = 0
    failed = 0
    
    for i, (g, k, p_float, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: g='{g}', k='{k}', p={p_float}")
        
        # Build automaton
        state_list, next_H, next_T, state_map = build_automaton(g, k)
        num_states = len(state_list)
        cocotb.log.info(f"  States: {num_states} ({state_list})")
        
        if num_states > MAX_STATES:
            cocotb.log.error(f"  FAIL: Number of states {num_states} exceeds MAX_STATES {MAX_STATES}")
            failed += 1
            continue
        
        # Compute exact probability
        exact = compute_exact_probability(g, k, p_float)
        cocotb.log.info(f"  Exact probability (Python): {exact:.10f}")
        
        # Convert p to fixed-point
        p_fixed = float_to_fixed(p_float)
        cocotb.log.info(f"  p_fixed = {p_fixed} (0x{p_fixed:08X})")
        
        # Write inputs to DUT
        # num_states
        if has_signal(dut, 'num_states'):
            dut.num_states.value = num_states
        # next_H and next_T arrays
        if has_signal(dut, 'next_H'):
            # Try 2D array first
            try:
                for j in range(num_states):
                    dut.next_H[j].value = next_H[j]
            except (AttributeError, TypeError):
                # Individual ports
                for j in range(num_states):
                    port_name = f'next_H_{j}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = next_H[j]
                    else:
                        raise TestFailure(f"Cannot find next_H[{j}]")
        else:
            raise TestFailure("Signal 'next_H' not found")
        if has_signal(dut, 'next_T'):
            try:
                for j in range(num_states):
                    dut.next_T[j].value = next_T[j]
            except (AttributeError, TypeError):
                for j in range(num_states):
                    port_name = f'next_T_{j}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = next_T[j]
                    else:
                        raise TestFailure(f"Cannot find next_T[{j}]")
        else:
            raise TestFailure("Signal 'next_T' not found")
        # p
        if has_signal(dut, 'p'):
            dut.p.value = p_fixed
        else:
            raise TestFailure("Signal 'p' not found")
        
        # Start computation
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            result_fixed = int(dut.result.value)
        else:
            # Combinational: wait a bit
            await Timer(100, units='ns')
            result_fixed = int(dut.result.value)
        
        result_float = fixed_to_float(result_fixed)
        cocotb.log.info(f"  DUT result (fixed): {result_fixed} (0x{result_fixed:08X})")
        cocotb.log.info(f"  DUT result (float): {result_float:.10f}")
        
        # Compare with tolerance 1e-6
        diff = abs(result_float - exact)
        rel_diff = diff / max(1.0, abs(exact))
        if rel_diff <= 1e-6:
            cocotb.log.info(f"  PASS: diff = {diff:.10f}, rel = {rel_diff:.10f}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: diff = {diff:.10f}, rel = {rel_diff:.10f} (expected ≤ 1e-6)")
            failed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")