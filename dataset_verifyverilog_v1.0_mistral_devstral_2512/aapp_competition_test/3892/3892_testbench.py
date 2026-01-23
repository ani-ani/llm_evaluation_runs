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
# TESTCASE GENERATION
# ============================================================================

def compute_expected(n, m, candies):
    """Compute expected answers for a test case (1-indexed candies)."""
    # Convert to 0‑indexed
    n0 = n
    count = [0] * n0
    min_dist = [n0] * n0  # initialize to n (max possible distance)
    
    for a, b in candies:
        a0 = a - 1
        b0 = b - 1
        dist = (b0 - a0) % n0
        count[a0] += 1
        if dist < min_dist[a0]:
            min_dist[a0] = dist
    
    answers = [0] * n0
    for i in range(n0):
        best = 0
        for j in range(n0):
            if count[j] > 0:
                # distance from i to j
                d_ij = (j - i) % n0
                value = d_ij + (count[j] - 1) * n0 + min_dist[j]
                if value > best:
                    best = value
        answers[i] = best
    return answers

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_toy_train(dut):
    """Main test function for Toy Train module."""
    
    # Detect module type (sequential)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("Module must have 'clk' and 'done' signals (sequential)")
    
    # Start clock (10 ns period)
    CLK_PERIOD_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        # (n, m, [(a1,b1), (a2,b2), ...], description)
        (5, 7, [(2,4), (5,1), (2,3), (3,4), (4,1), (5,3), (3,5)], "Example 1"),
        (2, 3, [(1,2), (1,2), (1,2)], "Example 2"),
        (3, 1, [(3,1)], "Single candy"),
        (5, 1, [(3,2)], "One candy different"),
        (10, 2, [(9,2), (10,8)], "Small n, few candies"),
        (100, 1, [(7,75)], "Max n, single candy"),
        (5, 3, [(1,2), (4,3), (1,5)], "Mixed stations"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, m, candies, description) in enumerate(test_cases):
        dut._log.info(f"Running test {test_idx+1}: {description}")
        
        # Prepare inputs
        # Arrays are 200 elements, we only fill first m
        a_vals = [0] * 200
        b_vals = [0] * 200
        for i, (a, b) in enumerate(candies):
            a_vals[i] = a
            b_vals[i] = b
        
        # Write inputs
        dut.n.value = n
        dut.m.value = m
        await write_array(dut, 'a_i', a_vals, 7)  # 7 bits for a_i
        await write_array(dut, 'b_i', b_vals, 7)  # 7 bits for b_i
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=20000)
        
        # Read results
        results = await read_array(dut, 'ans_i', n)
        
        # Compute expected
        expected = compute_expected(n, m, candies)
        
        # Verify
        try:
            for i in range(n):
                if not is_value_defined(results[i]):
                    raise TestFailure(f"Result[{i}] is undefined (X/Z)")
                if results[i] != expected[i]:
                    raise TestFailure(f"Station {i+1}: expected {expected[i]}, got {results[i]}")
            dut._log.info(f"  PASS: All {n} stations correct")
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    # Summary
    dut._log.info("="*60)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")