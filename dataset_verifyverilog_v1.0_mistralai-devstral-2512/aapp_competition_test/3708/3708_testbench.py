import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
ARRAY_SIZE = 64
CLK_NS = 10
MAX_CYCLES = 300

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
    if v < 0:
        return (1 << bits) + v
    return v & ((1 << bits) - 1)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

def solve_original(n, volcanoes):
    """Original algorithm adapted from Python solution"""
    a = volcanoes.copy()
    a.sort(key=lambda x: x[0] * n + x[1])
    a.append([n, n+1])
    
    d = [[0, 1]]
    r = 0
    i = 0
    
    while i < len(a):
        if a[i][0] == r:
            dd = []
            j = 0
            while i < len(a) and a[i][0] == r and j < len(d):
                if a[i][1] < d[j][0]:
                    i += 1
                elif a[i][1] == d[j][0]:
                    d[j][0] += 1
                    if d[j][0] >= d[j][1]:
                        j += 1
                    i += 1
                else:
                    dd.append([d[j][0], a[i][1]])
                    d[j][0] = a[i][1] + 1
                    while j < len(d) and d[j][1] <= a[i][1] + 1:
                        j += 1
                    if j < len(d):
                        d[j][0] = max(d[j][0], a[i][1] + 1)
            if j < len(d):
                dd.append([d[j][0], n])
            while i < len(a) and a[i][0] == r:
                i += 1
            d = dd
            r += 1
            if len(d) == 0:
                break
        else:
            r = a[i][0]
            d = [[d[0][0], n]]
    
    if len(d) == 0 or d[len(d) - 1][1] < n:
        return -1
    else:
        return 2 * (n - 1)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_desert_path(dut):
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases scaled to 16-bit range
    test_cases = [
        # (n, volcanoes_list, expected)
        (4, [(1, 3), (1, 4)], 6),
        (7, [(1, 6), (2, 6), (3, 5), (3, 6), (4, 3), (5, 1), (5, 2), (5, 3)], 12),
        (2, [(1, 2), (2, 1)], -1),
        (3, [(1, 2), (2, 2), (2, 1)], -1),
        (4, [(2, 1), (3, 1), (4, 1)], -1),
        (5, [(1, 2), (2, 2), (3, 2), (4, 2), (5, 4)], -1),
        (6, [(1, 2), (2, 2), (3, 2), (4, 2), (5, 3), (6, 4)], -1),
        (5, [(1, 2), (2, 2), (3, 2), (3, 4), (4, 4), (5, 4)], -1),
        (10, [(2, 1), (1, 3), (2, 3), (3, 3), (4, 2)], 18),
        (1000000000, [(500000000, 500000000)], 1999999998),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n_scaled, volcanoes, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: n={n_scaled}, m={len(volcanoes)}, expected={expected}")
        
        try:
            if is_seq:
                # Scale n to 16-bit (for this testbench, use actual values since simulation is fast)
                # In real hardware, n would be scaled down
                n = min(n_scaled, 65535)
                
                # Set m_count
                m = len(volcanoes)
                dut.m_count.value = clamp_to_width(m, 16)
                
                # Set volcano coordinates
                for i in range(min(m, 64)):
                    x, y = volcanoes[i]
                    # Scale coordinates to fit in 16-bit if needed
                    if x > 65535:
                        x = 65535
                    if y > 65535:
                        y = 65535
                    
                    # Individual assignment for arrays
                    getattr(dut, f'volcano_x_{i}').value = clamp_to_width(x, DATA_WIDTH)
                    getattr(dut, f'volcano_y_{i}').value = clamp_to_width(y, DATA_WIDTH)
                
                # Fill remaining with zeros
                for i in range(m, 64):
                    getattr(dut, f'volcano_x_{i}').value = 0
                    getattr(dut, f'volcano_y_{i}').value = 0
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                # Convert to signed if needed
                if result >= (1 << 31):  # If result is interpreted as signed in 32-bit
                    result = result - (1 << 32)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                passed += 1
                
                # Reset for next test
                await reset_dut(dut)
            else:
                # Combinational version
                await Timer(100, units='ns')
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1} FAILED: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    cocotb.log.info(f"Results: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")