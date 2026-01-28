import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_FACTORS = 16
CLK_NS = 10
MAX_CYCLES = 512

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def factorize(n: int):
    factors = []
    d = 2
    while d * d <= n:
        while n % d == 0:
            factors.append(d)
            n //= d
        d += 1
    if n > 1:
        factors.append(n)
    return factors

# Test cases
TEST_CASES = [
    (2, [2]),
    (4, [2, 2]),
    (8, [2, 2, 2]),
    (57, [3, 19]),  # 3*19
    (1083, [3, 3, 19, 19]),  # 3*19*3*19
    (6193, [3, 3, 3, 19, 19, 19]),  # 3*19*3*19*3*19
    (10837, [3, 19, 19, 19]),  # 3*19*19*19
    (18, [2, 3, 3]),  # 2*3*3
]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_factorize(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for idx, (n_in, expected_factors) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {idx+1}: factorize({n_in})")
        
        try:
            # Set input n
            dut.n.value = clamp_to_width(n_in, DATA_WIDTH)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.valid_len.value):
                raise TestFailure("valid_len undefined")
            
            valid_len = int(dut.valid_len.value)
            if valid_len == 0:
                raise TestFailure(f"valid_len is zero for n={n_in}")
            
            if valid_len > MAX_FACTORS:
                raise TestFailure(f"valid_len {valid_len} exceeds max {MAX_FACTORS}")
            
            factors = []
            for i in range(valid_len):
                # Check if factor signal exists
                factor_sig = None
                try:
                    factor_sig = getattr(dut, f'factors_{i}')
                except AttributeError:
                    # Try array access
                    if hasattr(dut, 'factors'):
                        factor_sig = dut.factors[i]
                    else:
                        raise TestFailure(f"Could not access factors[{i}]")
                
                if not is_value_defined(factor_sig.value):
                    raise TestFailure(f"factors[{i}] undefined")
                
                val = int(factor_sig.value)
                factors.append(val)
            
            # Compare with expected
            if factors != expected_factors:
                raise TestFailure(f"Expected {expected_factors}, got {factors}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: n={n_in}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")