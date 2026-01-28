import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 66000  # Slightly more than 65536

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference implementation for validation
def fizz_buzz_reference(n: int) -> int:
    count = 0
    for x in range(n):
        if x % 11 == 0 or x % 13 == 0:
            # Count digit 7 in x's decimal representation
            temp = x
            if temp == 0:
                continue  # 0 has no 7s
            while temp > 0:
                if temp % 10 == 7:
                    count += 1
                temp //= 10
    return count

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fizz_buzz_counter(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, expected_count, description)
    test_cases = [
        (50, 0, "n=50: no 7s in multiples of 11/13"),
        (78, 2, "n=78: 77 (two 7s)"),
        (79, 3, "n=79: 77 (two 7s) + one more"),
        (100, 3, "n=100: 77 (two 7s) + 91 (one 7)"),
        (200, 6, "n=200: verify count"),
        (4000, 192, "n=4000: scaled test"),
        (10000, 639, "n=10000: larger test"),
        (100000, 8026, "n=100000: max scaled test")
    ]
    
    passed = failed = 0
    
    for i, (n, exp, desc) in enumerate(test_cases):
        # Scale down for hardware constraints
        if n > 65535:
            cocotb.log.info(f"Test {i+1}: {desc} - n={n} scaled to 65535")
            n = 65535
            exp = fizz_buzz_reference(n)  # Recompute expected for scaled n
        
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, expected={exp})")
        
        try:
            if is_seq:
                # Start computation
                dut.n.value = clamp_to_width(n, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = safe_int(dut.count.value)
            else:
                # Combinational
                dut.n.value = clamp_to_width(n, DATA_WIDTH)
                await Timer(100, units='ns')
                result = safe_int(dut.count.value)
            
            if not is_value_defined(dut.count.value):
                raise TestFailure("Result count undefined")
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} (n={n})")
            
            cocotb.log.info(f"  PASS: {exp}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
