import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 8
MAX_VAL = (1 << DATA_WIDTH) - 1

def count_triples_py(n):
    count = 0
    for a in range(1, n):
        for b in range(a, n):
            sum_sq = (a*a + b*b) % n
            for c in range(1, n):
                if (c*c) % n == sum_sq:
                    count += 1
    return count

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'n'): dut.n.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_pythagorean_mod(dut):
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [7, 15, 20, 30]
    passed = 0
    failed = 0
    
    for n in test_cases:
        if n > 256:
            cocotb.log.info(f"Skipping n={n} > 256")
            continue
            
        expected = count_triples_py(n)
        cocotb.log.info(f"Testing n={n}, expecting {expected}")
        
        try:
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"For n={n}: Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n} result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")