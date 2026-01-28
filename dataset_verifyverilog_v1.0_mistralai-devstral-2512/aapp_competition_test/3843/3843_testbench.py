import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 15000

# Helper functions from rules
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Expected Python reference implementation for test cases
def reference_solution(n, m):
    def digits_needed(x):
        if x <= 1:
            return 1
        cnt = 0
        x -= 1
        while x > 0:
            x //= 7
            cnt += 1
        return max(1, cnt)
    
    dh = digits_needed(n)
    dm = digits_needed(m)
    
    if dh + dm > 7:
        return 0
    
    # Generate all permutations of dh+dm digits from 0-6
    from itertools import permutations
    total = 0
    for perm in permutations(range(7), dh + dm):
        # Hours: first dh digits
        hours = 0
        for i in range(dh):
            hours = hours * 7 + perm[i]
        # Minutes: last dm digits
        minutes = 0
        for i in range(dh, dh + dm):
            minutes = minutes * 7 + perm[i]
        if hours < n and minutes < m:
            total += 1
    return total

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_robbers_watches(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (2, 3, 4),      # Sample 1
        (8, 2, 5),      # Sample 2
        (1, 1, 0),      # Edge: both need 1 digit, total 2 <=7, but (0,0) fails distinct
        (1, 2, 1),      # (0,1) valid
        (8, 8, 0),      # dh=2 (7 needs 2 digits), dm=2, total 4 <=7, but all pairs overlap
        (50, 50, 0),    # dh=2 (49 needs 2 digits), dm=2, 4 <=7, but constraints tight
        (344, 344, 0),  # dh=3 (343 needs 3), dm=3, total 6 <=7, but bounds exclude
        (16808, 7, 720),
        (2402, 50, 0),
        (343, 2401, 5040),
        (1582, 301, 2874),
        (2401, 343, 5040),
        (2, 1, 1),
        (8, 7, 35),
        (50, 7, 120),
        (2402, 49, 720),
        (123, 123, 360),
        (123, 456, 150),
        (1, 9, 0),
        (1, 10, 1),
        (50, 67, 6),
        (7, 117649, 5040),
        (2400, 342, 5040),
        (2400, 227, 3360),
        (117648, 5, 3600),
        (16808, 41, 0),
        (3, 16808, 240),
        (823542, 3, 0),
        (3, 823544, 0),
        (117650, 5, 0),
        (50, 50, 0),
        (50, 3, 40),
        (2402, 343, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, m={m_val}, expected={expected}")
        
        try:
            if has_signal(dut, 'clk'):
                # Sequential operation
                dut.n.value = clamp_to_width(n_val, 32)
                dut.m.value = clamp_to_width(m_val, 32)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational
                dut.n.value = clamp_to_width(n_val, 32)
                dut.m.value = clamp_to_width(m_val, 32)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")