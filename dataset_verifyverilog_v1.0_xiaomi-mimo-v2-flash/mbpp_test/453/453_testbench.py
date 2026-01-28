import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference Python implementation
def sumofFactors(n):
    if (n % 2 != 0):
        return 0
    res = 1
    for i in range(2, (int)(math.sqrt(n)) + 1):
        count = 0
        curr_sum = 1
        curr_term = 1
        while (n % i == 0):
            count = count + 1
            n = n // i
            if (i == 2 and count == 1):
                curr_sum = 0
            curr_term = curr_term * i
            curr_sum = curr_sum + curr_term
        res = res * curr_sum
    if (n >= 2):
        res = res * (1 + n)
    return res

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sum_even_factors(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (18, 26, "n=18 -> 26"),
        (30, 48, "n=30 -> 48"),
        (6, 8, "n=6 -> 8"),
        (2, 2, "n=2 -> 2"),
        (1, 0, "n=1 -> 0 (odd)"),
        (65535, 0, "n=65535 -> 0 (odd)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n_val, 16)
            elif has_signal(dut, 'n_0'):
                # For individual wires
                for bit in range(16):
                    getattr(dut, f'n_{bit}').value = (n_val >> bit) & 1
            else:
                raise TestFailure("No input 'n' signal found")
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
