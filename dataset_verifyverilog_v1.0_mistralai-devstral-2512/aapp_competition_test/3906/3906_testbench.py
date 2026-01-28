import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Constants
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 66000  # Max for 16-bit inputs (2 * 32768 safety margin)

# Fibonacci calculation in Python for verification
def fib_py(n):
    if n == 0:
        return 1
    if n == 1:
        return 2
    a, b = 1, 2
    for _ in range(2, n + 1):
        a, b = b, (a + b) % MOD
    return b

def calculate_expected(n_val, m_val):
    # Handle n=0, m=0 (though inputs are >=1)
    if n_val == 1:
        fib_n = 1  # fib(0)
    else:
        fib_n = fib_py(n_val - 1)
    
    if m_val == 1:
        fib_m = 1  # fib(0)
    else:
        fib_m = fib_py(m_val - 1)
    
    result = ((fib_n + fib_m - 1) * 2) % MOD
    return result

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_pictures(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (n, m, expected)
    test_cases = [
        (2, 3, 8),
        (1, 2, 4),
        (1, 1, 2),
        (2, 1, 4),
        (1, 3, 6),
        (3, 1, 6),
        (2, 5, 18),
        (3, 6, 30),
        (2, 2, 6),
        (5, 5, 222),  # Additional test
        (10, 10, 35832),  # Additional test
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, m={m_val}, expected={exp}")
        try:
            if is_seq:
                # Set inputs
                if has_signal(dut, 'n'):
                    dut.n.value = clamp_to_width(n_val, 16)
                if has_signal(dut, 'm'):
                    dut.m.value = clamp_to_width(m_val, 16)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
            else:
                # Combinational - set inputs and wait
                if has_signal(dut, 'n'):
                    dut.n.value = clamp_to_width(n_val, 16)
                if has_signal(dut, 'm'):
                    dut.m.value = clamp_to_width(m_val, 16)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {n_val}x{m_val} -> {exp}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")