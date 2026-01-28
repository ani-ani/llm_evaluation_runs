import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MOD = 1000000009
MAX_N = 16  # Scaled constraint
MAX_M = 16  # Scaled constraint
DATA_WIDTH = 32
CLK_NS = 10

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

def compute_expected(n, m):
    # Python reference logic
    if n == 0:
        return 1
    p = pow(2, m, MOD)
    # result = prod_{i=0}^{n-1} (p - 1 - i)
    res = 1
    for i in range(n):
        term = (p - 1 - i) % MOD
        res = (res * term) % MOD
    return res

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wool_sequences(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases scaled for constraints
    test_cases = [
        (3, 2, "Example from problem"),
        (4, 2, "n=4, m=2"),
        (1, 2, "n=1, m=2"),
        (5, 10, "Random small"),
        (16, 16, "Max bounds"),
        (0, 0, "Zero inputs")
    ]
    
    passed = 0
    failed = 0
    
    for n, m, desc in test_cases:
        # Skip if inputs exceed simulated constraints, though logic should handle them
        if n > MAX_N or m > MAX_M:
            cocotb.log.info(f"Skipping {desc} (n={n}, m={m}) due to test constraints")
            continue
            
        cocotb.log.info(f"Running test: {desc} (n={n}, m={m})")
        
        try:
            # Calculate expected
            expected = compute_expected(n, m)
            
            # Apply inputs
            dut.n_in.value = n
            dut.m_in.value = m
            
            if is_seq:
                # Start sequence
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not has_signal(dut, 'result'):
                    raise TestFailure("Result signal missing")
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X or Z)")
                    
                actual = int(dut.result.value)
            else:
                # Combinational logic
                await Timer(100, units='ns')
                actual = int(dut.result.value)
            
            if actual != expected:
                raise TestFailure(f"Mismatch: Expected {expected}, Got {actual}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (n={n}, m={m}): {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
