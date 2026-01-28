import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 16

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference for 2^n mod p
def python_modp(n, p):
    if p == 0:
        return 0  # Division by zero, return 0
    if p == 1:
        return 0  # 2^n mod 1 = 0 for any n
    if n == 0:
        return 1 % p
    result = 1
    base = 2
    # Binary exponentiation
    for i in range(8):  # 8-bit n
        if (n >> i) & 1:
            result = (result * base) % p
        base = (base * base) % p
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_modp(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (3, 5, 3, "3^2=8 mod5=3"),
        (1101, 101, 2, "large exponent"),
        (0, 101, 1, "2^0=1 mod101=1"),
        (3, 11, 8, "3^2=8 mod11=8"),
        (100, 101, 1, "100 exp"),
        (30, 5, 4, "30 exp"),
        (31, 5, 3, "31 exp"),
        (255, 255, 0, "max exp mod max p"),
        (0, 1, 0, "2^0 mod1=0"),
        (1, 1, 0, "2^1 mod1=0"),
    ]
    
    passed = failed = 0
    
    for i, (n, p, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, p={p}, expected={expected})")
        try:
            # Scale inputs to 8-bit
            n_scaled = n & 0xFF
            p_scaled = p & 0xFF
            
            # Apply to DUT
            if is_seq:
                dut.n.value = n_scaled
                dut.p.value = p_scaled
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=20)
            else:
                # Combinational, assume instant
                await Timer(1, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    cocotb.log.info(f"All {passed} tests passed")