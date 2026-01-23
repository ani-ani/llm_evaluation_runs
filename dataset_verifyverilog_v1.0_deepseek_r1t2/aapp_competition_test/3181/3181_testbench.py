import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def ceil_sqrt(n):
    if n <= 1:
        return 1
    return int(math.ceil(math.sqrt(n)))

# Verification algorithms
def lis_length(arr):
    if not arr:
        return 0
    n = len(arr)
    dp = [1] * n
    for i in range(1, n):
        for j in range(i):
            if arr[j] < arr[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)

def lds_length(arr):
    if not arr:
        return 0
    n = len(arr)
    dp = [1] * n
    for i in range(1, n):
        for j in range(i):
            if arr[j] > arr[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)

def monotone_length(arr):
    return max(lis_length(arr), lds_length(arr))

# Sequential helpers
async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def collect_sequence(dut, N):
    """Collect N elements after first valid appears."""
    sequence = []
    # Wait for first valid after start
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for first valid")
    
    # Read first element
    val = int(dut.data.value)
    sequence.append(val)
    cocotb.log.info(f"  Element 0: {val}")
    
    # Read remaining N-1 elements
    for i in range(1, N):
        await RisingEdge(dut.clk)
        if not (is_value_defined(dut.valid.value) and int(dut.valid.value) == 1):
            raise TestFailure(f"Valid not high for element {i}")
        val = int(dut.data.value)
        sequence.append(val)
        cocotb.log.info(f"  Element {i}: {val}")
    
    return sequence

# Main test
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_monotone_seq_generator(dut):
    """Test monotone sequence generator."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (4, 3, True, "N=4, K=3 (valid)"),
        (5, 1, False, "N=5, K=1 (invalid - too small)"),
        (5, 5, True, "N=5, K=5 (sorted)"),
        (4, 2, True, "N=4, K=2"),
        (1, 1, True, "N=1, K=1"),
        (16, 4, True, "N=16, K=4"),
        (6, 3, True, "N=6, K=3"),
        (9, 3, True, "N=9, K=3"),
    ]
    
    passed = 0
    failed = 0
    
    for N, K, should_pass, description in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test: {description}")
        cocotb.log.info(f"N={N}, K={K}, Expected: {'PASS' if should_pass else 'FAIL'}")
        
        try:
            dut.N.value = N
            dut.K.value = K
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Check error flag
            if has_signal(dut, 'error') and int(dut.error.value) == 1:
                if should_pass:
                    raise TestFailure("Unexpected error flag")
                cocotb.log.info("  Result: Invalid (as expected)")
                passed += 1
                continue
            
            if not should_pass:
                raise TestFailure("Expected error but DUT succeeded")
            
            # Collect and verify sequence
            sequence = await collect_sequence(dut, N)
            
            if len(sequence) != N:
                raise TestFailure(f"Length {len(sequence)} != N={N}")
            
            if sorted(sequence) != list(range(1, N+1)):
                raise TestFailure(f"Not a permutation of 1..N")
            
            mono_len = monotone_length(sequence)
            if mono_len != K:
                raise TestFailure(f"Longest monotone {mono_len} != K={K}")
            
            cocotb.log.info(f"  Sequence: {sequence}")
            cocotb.log.info(f"  LIS: {lis_length(sequence)}, LDS: {lds_length(sequence)}")
            cocotb.log.info("  Result: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Result: FAIL - {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")