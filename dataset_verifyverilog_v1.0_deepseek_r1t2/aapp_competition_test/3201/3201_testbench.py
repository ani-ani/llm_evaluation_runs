import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 8
MAX_K = 255
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # Allow more cycles for sorting

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

async def write_array(dut, arr):
    """Write array values to individual ports a0..a7."""
    for i in range(8):
        if i < len(arr):
            getattr(dut, f'a{i}').value = clamp_to_width(arr[i], DATA_WIDTH)
        else:
            getattr(dut, f'a{i}').value = 0

async def read_signal(dut, signal_name, default=0):
    """Safely read a signal, returning default if not found or undefined."""
    try:
        sig = getattr(dut, signal_name)
        if is_value_defined(sig.value):
            return int(sig.value)
    except AttributeError:
        pass
    return default

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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def collect_outputs(dut, K):
    """Collect K hash outputs using valid signal."""
    results = []
    timeout = MAX_CYCLES
    while len(results) < K and timeout > 0:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            if is_value_defined(dut.hash.value):
                results.append(int(dut.hash.value))
            else:
                raise TestFailure(f"Hash output undefined at cycle {len(results)+1}")
        timeout -= 1
    
    if len(results) < K:
        raise TestFailure(f"Only {len(results)} outputs received, expected {K}")
    
    return results

# ============================================================================
# EXPECTED OUTPUT GENERATOR
# ============================================================================

def generate_expected(N, K, B, M, arr):
    """Generate expected hashes using Python."""
    # Generate all non-empty subsequences
    subsequences = []
    for mask in range(1, 1 << N):
        subseq = []
        for i in range(N):
            if mask & (1 << i):
                subseq.append(arr[i])
        # Compute hash
        h = 0
        for v in subseq:
            h = (h * B + v) % M
        subsequences.append((subseq, h))
    
    # Sort lexicographically
    subsequences.sort(key=lambda x: x[0])
    
    # Extract first K hashes
    return [h for (_, h) in subsequences[:K]]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_subsequence_hash(dut):
    """Main test for SubsequenceHash module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, K, B, M, arr, description)
    test_cases = [
        (2, 3, 1, 5, [1, 2], "Sample 1: N=2, K=3, B=1, M=5, arr=[1,2]"),
        (3, 4, 2, 3, [1, 3, 1], "Sample 2: N=3, K=4, B=2, M=3, arr=[1,3,1]"),
        (4, 6, 23, 1000, [1, 2, 4, 2], "N=4, K=6, B=23, M=1000, arr=[1,2,4,2]"),
        (1, 1, 5, 10, [7], "Single element, K=1"),
        (5, 5, 1, 7, [1, 1, 1, 1, 1], "All same elements"),
        (3, 7, 10, 100, [5, 3, 4], "N=3, K=7 (max)"),
    ]
    
    total_passed = 0
    total_failed = 0
    
    for i, (N, K, B, M, arr, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        # Generate expected
        expected = generate_expected(N, K, B, M, arr)
        cocotb.log.info(f"  Expected: {expected}")
        
        # Write inputs
        await write_array(dut, arr)
        dut.N.value = clamp_to_width(N, 4)
        dut.K.value = clamp_to_width(K, 8)
        dut.B.value = clamp_to_width(B, 16)
        dut.M.value = clamp_to_width(M, 16)
        
        # Start computation
        await start_computation(dut)
        
        # Collect outputs
        try:
            results = await collect_outputs(dut, K)
            cocotb.log.info(f"  Results: {results}")
            
            # Compare
            if results == expected:
                cocotb.log.info(f"  PASS")
                total_passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected {expected}, got {results}")
                total_failed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            total_failed += 1
        
        # Wait for done to be high (should already be done)
        try:
            await wait_for_done(dut, 100)
            # Clear any remaining valid signals
            await RisingEdge(dut.clk)
        except TestFailure:
            # Done not required immediately after outputs
            pass
        
        # Reset between tests
        await reset_dut(dut, 2)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Summary: {total_passed}/{total_passed+total_failed} tests passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} tests failed")