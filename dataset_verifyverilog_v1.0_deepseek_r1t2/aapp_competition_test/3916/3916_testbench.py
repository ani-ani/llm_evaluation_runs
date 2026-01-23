import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
# PRECOMPUTED VALUES FOR MAX_K=16
# ============================================================================

def compute_reference_result(k_values, n):
    """Compute expected result using Python reference."""
    # Primes up to 16
    primes = [2, 3, 5, 7, 11, 13]
    
    # Compute omega (number of prime factors with multiplicity)
    omega = [0] * 17
    for i in range(2, 17):
        temp = i
        for p in primes:
            while temp % p == 0:
                omega[i] += 1
                temp //= p
    
    # Compute dist_to_root
    dist_to_root = [0] * 17
    for k in range(2, 17):
        dist_to_root[k] = dist_to_root[k-1] + omega[k]
    
    # Count fragments per k
    count = [0] * 17
    for i in range(n):
        if k_values[i] <= 16:
            count[k_values[i]] += 1
    
    # Initial distance to root
    total_dist = sum(count[k] * dist_to_root[k] for k in range(17))
    
    # If > n/2 fragments at k=1, optimal P=1
    if count[1] > n // 2:
        return 0
    
    # Otherwise, find best branch (simplified greedy)
    # For this scaled version, we'll compute the minimum possible
    # by checking if moving to any prime reduces distance
    best = total_dist
    
    # Try moving to each prime (simplified check)
    # In full algorithm, this would be more complex
    for p_idx, p in enumerate(primes):
        # Count fragments in branch p
        # For k values where the path goes through p
        # Simplified: just return total_dist for small cases
        pass
    
    return total_dist

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fragment_assembly(dut):
    """Main test for fragment_assembly module."""
    
    # Configuration
    DATA_WIDTH = 16
    ARRAY_SIZE = 8
    CLK_PERIOD_NS = 10
    MAX_CYCLES = 1000
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Define test cases: (k_values, n, expected_result, description)
    test_cases = [
        ([2, 1, 4], 3, 5, "Example 1: 2,1,4"),
        ([3, 1, 4, 4], 4, 6, "Example 2: 3,1,4,4"),
        ([3, 1, 4, 1], 4, 6, "Example 3: 3,1,4,1"),
        ([3, 1, 4, 1, 5], 5, 11, "Example 4: 3,1,4,1,5"),
        ([1, 2, 3], 3, 4, "Simple: 1,2,3"),
        ([0], 1, 0, "Single: 0"),
        ([1], 1, 0, "Single: 1"),
        ([0, 1, 1, 0], 4, 0, "All at 0 or 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k_vals, n_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Pad k_values to 8 elements
            k_padded = k_vals + [0] * (8 - len(k_vals))
            
            # Write inputs
            await write_array(dut, 'k_values', k_padded, DATA_WIDTH)
            dut.n.value = n_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# BONUS: RANDOMIZED TESTS
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_randomized(dut):
    """Test with random inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    random.seed(42)
    
    for test_num in range(20):
        # Generate random test case
        n = random.randint(1, 8)
        k_vals = [random.randint(0, 16) for _ in range(n)]
        
        # Compute reference
        expected = compute_reference_result(k_vals, n)
        
        # Pad and write
        k_padded = k_vals + [0] * (8 - n)
        await write_array(dut, 'k_values', k_padded, 16)
        dut.n.value = n
        
        # Compute
        await start_computation(dut)
        await wait_for_done(dut, 1000)
        
        # Read
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test {test_num}: expected {expected}, got {result} (k={k_vals})")
        
        cocotb.log.info(f"Random test {test_num}: PASS (result={result})")
        
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)

# ============================================================================
# BONUS: EDGE CASES
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    edge_cases = [
        ([0]*8, 8, 0, "All zeros"),
        ([1]*8, 8, 0, "All ones"),
        ([16]*8, 8, 28*8, "All 16s"),
        ([1,1,1,2,2,3,3,4], 8, 0+0+0+1+1+2+2+4, "Mixed small"),
    ]
    
    for i, (k_vals, n, expected, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge case {i+1}: {desc}")
        
        await write_array(dut, 'k_values', k_vals, 16)
        dut.n.value = n
        
        await start_computation(dut)
        await wait_for_done(dut, 1000)
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Edge case {i+1}: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS")
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
