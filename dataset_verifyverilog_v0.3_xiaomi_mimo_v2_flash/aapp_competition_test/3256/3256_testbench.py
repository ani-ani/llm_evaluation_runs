import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 8
MAX_K = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================
async def write_array(dut, values):
    """Write values to arr[0..N-1] individually."""
    for i in range(N):
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = clamp_to_width(values[i], DATA_WIDTH)
        elif hasattr(dut, 'arr'):
            dut.arr[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find array signal for index {i}")

# ============================================================================
# RESET AND WAIT HELPERS
# ============================================================================
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# EXPECTED RESULT COMPUTATION (Python reference)
# ============================================================================
def get_compositions(N, K):
    """Return list of compositions of N into K parts."""
    if K == 1:
        return [[N]]
    result = []
    for first in range(1, N - K + 2):
        for rest in get_compositions(N - first, K - 1):
            result.append([first] + rest)
    return result

def compute_expected(arr, K):
    """Compute maximum AND for circle of arr (length N) and K sections."""
    N = len(arr)
    max_val = 0
    for start in range(N):
        b = [arr[(start + i) % N] for i in range(N)]
        compositions = get_compositions(N, K)
        for comp in compositions:
            pos = 0
            seg_ors = []
            for length in comp:
                seg_or = 0
                for i in range(length):
                    seg_or |= b[pos + i]
                seg_ors.append(seg_or)
                pos += length
            and_val = seg_ors[0]
            for v in seg_ors[1:]:
                and_val &= v
            if and_val > max_val:
                max_val = and_val
    return max_val

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_and_circle(dut):
    """Test the max_and_circle module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (arr, K, description)
    test_cases = [
        ([2, 3, 4, 1, 0, 0, 0, 0], 2, "Sample 1 padded to N=8"),
        ([2, 2, 2, 4, 4, 4, 0, 0], 3, "Sample 2 padded to N=8"),
        ([0, 1, 2, 3, 0, 0, 0, 0], 1, "Sample 3 padded to N=8"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 4, "All distinct"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 2, "All zeros"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, K, description) in enumerate(test_cases):
        if K > MAX_K:
            cocotb.log.warning(f"Skipping test {i+1}: K={K} exceeds MAX_K={MAX_K}")
            continue
        
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            await write_array(dut, arr)
            dut.k.value = K
            
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected = compute_expected(arr, K)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
