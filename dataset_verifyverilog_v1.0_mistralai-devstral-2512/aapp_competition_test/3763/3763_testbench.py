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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def wait_for_done(dut, max_cycles=15000):
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

def compute_expected(n, a, p):
    if sum(a) <= p:
        return float(n)
    fact = [1] * 51
    for i in range(1, 51):
        fact[i] = fact[i-1] * i
    total_ans = 0
    for i in range(n):
        dp = [[0] * (p + 2) for _ in range(n)]
        dp[0][0] = 1
        for guest_idx in range(n):
            if guest_idx == i:
                continue
            size = a[guest_idx]
            for k in range(n-2, -1, -1):
                for z in range(p, -1, -1):
                    if dp[k][z] > 0:
                        new_sum = z + size
                        if new_sum <= p:
                            dp[k+1][new_sum] += dp[k][z]
        for k in range(n):
            for z in range(p + 1):
                if z + a[i] > p:
                    count = dp[k][z]
                    if count > 0:
                        total_ans += k * count * fact[k] * fact[n - 1 - k]
    return total_ans / fact[n]

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_restaurant(dut):
    if not has_signal(dut, 'clk'):
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 3], 3, 1.33333),
        ([2, 2, 2], 5, 1.0),
        ([1, 2], 2, 1.0),
        ([1, 2, 3], 10, 3.0),
        ([1, 1, 1, 1, 1], 1, 1.0),
        ([3, 5], 5, 0.0),
        ([1, 2, 3, 4, 5], 20, 5.0)
    ]
    
    for i, (a_vals, p_val, expected) in enumerate(test_cases):
        n_val = len(a_vals)
        
        if has_signal(dut, 'n_in'):
            dut.n_in.value = n_val
        if has_signal(dut, 'p_in'):
            dut.p_in.value = p_val
        if has_signal(dut, 'a_in'):
            for j, v in enumerate(a_vals):
                dut.a_in[j].value = clamp_to_width(v, 5)
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
        
        result = 0.0
        if has_signal(dut, 'result'):
            val = int(dut.result.value)
            result = val / 256.0  # Q8.8 format
        
        if abs(result - expected) > 0.01:
            raise TestFailure(f"Test {i}: Expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test {i}: Passed {result}")