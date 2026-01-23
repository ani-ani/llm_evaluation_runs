import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16      # Denominations and k are 16-bit
REMAINDER_WIDTH = 5  # Since k ≤ 32, remainders fit in 5 bits
ARRAY_SIZE = 8       # Maximum denominations
RESULT_SIZE = 32     # Maximum remainders
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def write_denominations(dut, denominations):
    """Write denominations to the input array."""
    for i in range(ARRAY_SIZE):
        if i < len(denominations):
            val = clamp_to_width(denominations[i], DATA_WIDTH)
        else:
            val = 0
        if has_signal(dut, f'denominations_{i}'):
            getattr(dut, f'denominations_{i}').value = val
        else:
            # Fallback to indexed array
            dut.denominations[i].value = val

async def read_remainders(dut, count):
    """Read the remainders array up to count elements."""
    results = []
    for i in range(min(count, RESULT_SIZE)):
        if has_signal(dut, f'remainders_{i}'):
            val = getattr(dut, f'remainders_{i}').value
        else:
            val = dut.remainders[i].value
        
        if is_value_defined(val):
            results.append(int(val))
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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
# GCD HELPER FOR TEST EXPECTATIONS
# ============================================================================

def compute_expected_gcd(a, b):
    """Compute GCD of two numbers."""
    while b:
        a, b = b, a % b
    return a

def compute_expected_results(denominations, n, k):
    """Compute expected results in Python."""
    # Compute GCD of all denominations and k
    g = k
    for i in range(n):
        g = compute_expected_gcd(g, denominations[i])
    
    # Generate set of remainders
    count = k // g
    remainders = set()
    for i in range(count):
        remainders.add((i * g) % k)
    
    return sorted(remainders)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_martian_tax(dut):
    """Test Martian Tax module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (denominations, n, k, expected_remainders, description)
    test_cases = [
        # Example 1: n=2, k=8, denominations=[12,20] -> [0,4]
        ([12, 20], 2, 8, [0, 4], "Original example 1"),
        # Example 2: n=3, k=10, denominations=[10,20,30] -> [0]
        ([10, 20, 30], 3, 10, [0], "Original example 2"),
        # Additional tests
        ([4, 6, 8], 3, 10, [0, 2, 4, 6, 8], "Multiple denominations"),
        ([5], 1, 10, [0, 5], "Single denomination"),
        ([7, 14], 2, 21, [0, 7, 14], "GCD=7"),
        ([2, 4, 6], 3, 8, [0, 2, 4, 6], "All even"),
        ([3, 6], 2, 9, [0, 3, 6], "GCD=3"),
        ([15], 1, 30, [0, 15], "Single large"),
        ([1], 1, 5, [0, 1, 2, 3, 4], "GCD=1"),
        ([6, 9], 2, 12, [0, 3, 6, 9], "GCD=3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (denominations, n, k, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Denominations: {denominations}, n={n}, k={k}")
        
        try:
            # Write inputs
            await write_denominations(dut, denominations)
            
            # Set n and k
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'k'):
                dut.k.value = k
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.count.value):
                raise TestFailure("Count is undefined (X/Z)")
            
            actual_count = int(dut.count.value)
            actual_remainders = await read_remainders(dut, actual_count)
            
            # Filter out None values
            actual_remainders = [r for r in actual_remainders if r is not None]
            
            # Verify count
            if actual_count != len(expected):
                raise TestFailure(f"Count mismatch: expected {len(expected)}, got {actual_count}")
            
            # Verify remainders
            if sorted(actual_remainders) != expected:
                raise TestFailure(f"Remainders mismatch: expected {expected}, got {sorted(actual_remainders)}")
            
            cocotb.log.info(f"  PASS: count={actual_count}, remainders={actual_remainders}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")