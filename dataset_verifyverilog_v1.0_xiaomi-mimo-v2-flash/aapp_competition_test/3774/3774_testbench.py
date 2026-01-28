import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Reference Python Implementation (Scaled) ---
def reference_max_chessmen(n_val, m_val):
    # Ensure n <= m
    if n_val > m_val:
        n_val, m_val = m_val, n_val
    
    # Scale logic based on provided Python solutions
    if n_val == 1:
        # Formula: 6*(m/6) + 2*max(0, m%6 - 3)
        # Note: This is the total count of pieces (2 per pair)
        m_mod6 = m_val % 6
        add = 0
        if m_mod6 > 3:
            add = m_mod6 - 3
        return (m_val // 6) * 6 + 2 * add
    elif n_val == 2:
        if m_val == 2:
            return 0
        elif m_val == 3 or m_val == 7:
            return 4  # 2 pairs * 2 = 4
        else:
            return n_val * m_val
    else:
        # General case: fill all if even, or leave one if odd
        if (n_val * m_val) % 2 == 0:
            return n_val * m_val
        else:
            return n_val * m_val - 1

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_chessmen(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, m, expected_result)
    # Covering boundaries, special cases, and large numbers (scaled down for HDL 16-bit limit)
    test_cases = [
        (2, 2, 0),
        (3, 3, 8),
        (1, 4, 2),
        (1, 6, 6),
        (7, 1, 6),
        (7, 2, 12),
        (2, 3, 4),
        (2, 5, 10),
        (4, 3, 12),
        (5, 5, 24),
        (2, 19, 38),
        (32, 32, 1024),
        (1, 1, 0),
        (2, 1, 0),
        (3, 1, 0),
        (1, 8, 6),
        (9, 1, 6),
        (1, 10, 8),
    ]

    passed = 0
    failed = 0

    for i, (n_val, m_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, m={m_val}, Expected={expected}")
        
        try:
            # Set inputs
            dut.n.value = n_val
            dut.m.value = m_val
            dut.start.value = 1
            
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: n={n_val}, m={m_val}: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
