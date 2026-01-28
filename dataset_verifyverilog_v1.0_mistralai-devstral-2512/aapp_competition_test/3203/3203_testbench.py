import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
ARRAY_SIZE = 8  # Max N for scaling
CLK_NS = 10
MAX_CYCLES = 10000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Convert percentage to Q8.8 fixed-point
def pct_to_q88(pct):
    # pct * 256 / 100 = pct * 2.56
    return (pct * 256) // 100

# Convert Q8.8 back to percentage (float)
def q88_to_pct(q88):
    return (q88 * 100) / 256.0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_prob_matrix(dut, prob_matrix, n):
    """Write probability matrix to dut.prob array."""
    # Clamp n to max 8
    n = min(n, 8)
    for i in range(n):
        for j in range(n):
            if i < len(prob_matrix) and j < len(prob_matrix[i]):
                val = prob_matrix[i][j]
                # Convert to Q8.8
                q88_val = pct_to_q88(val)
                # Clamp to 8-bit
                q88_val = clamp_to_width(q88_val, 8)
                if hasattr(dut, f'prob_{i}_{j}'):
                    getattr(dut, f'prob_{i}_{j}').value = q88_val
                elif hasattr(dut, 'prob'):
                    # Assuming dut.prob is a 2D array or flattened
                    # For individual elements: prob_0, prob_1, ...
                    idx = i * n + j
                    if idx < 400:  # Max 20x20
                        getattr(dut, f'prob_{idx}').value = q88_val
                else:
                    # Direct assignment to array if supported
                    try:
                        dut.prob[i][j].value = q88_val
                    except:
                        pass
    await Timer(10, units='ns')

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_bond_assignment(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        dut.rst_n.value = 1

    test_cases = [
        (2, [[100, 100], [50, 50]], 50.0),
        (2, [[0, 50], [50, 0]], 25.0),
        (3, [[25, 60, 100], [13, 0, 50], [12, 70, 90]], 9.1),
    ]

    passed = 0
    failed = 0

    for test_idx, (n, prob_matrix, expected_pct) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={n}, expected={expected_pct}%")
        
        try:
            # Write n
            if has_signal(dut, 'n'):
                dut.n.value = min(n, 8)  # Clamp to 8
            
            # Write probability matrix (scaled to Q8.8)
            await write_prob_matrix(dut, prob_matrix, n)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=5000)
            else:
                # Combinational: just wait
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_q88 = int(dut.result.value)
            result_pct = q88_to_pct(result_q88)
            
            # Check expected value with tolerance
            # For 9.1%, Q8.8 is approximately 23 (9.1*2.56=23.296)
            # Allow 0.5% absolute error (2.56 in Q8.8)
            tolerance = 0.5  # percentage points
            
            if abs(result_pct - expected_pct) > tolerance + 1e-6:
                raise TestFailure(
                    f"Expected {expected_pct:.3f}%, got {result_pct:.3f}% "
                    f"(Q8.8: {result_q88})"
                )
            
            cocotb.log.info(f"  PASS: {result_pct:.3f}% (Q8.8: {result_q88})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
