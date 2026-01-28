import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    if bits >= 64: return v
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_valid(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for valid_out after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_chocolate_cutting(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases: (n, m, k, expected_result)
    # Note: Large expected results (e.g., 500000000000000000) exceed 32-bit.
    # We will saturate them to 0xFFFFFFFF for the 32-bit HDL implementation.
    # For small cases, we match exactly.
    
    test_cases = [
        (3, 4, 1, 6),
        (6, 4, 2, 8),
        (2, 3, 4, 0xFFFFFFFF), # -1
        (10, 10, 2, 30),
        (6, 4, 5, 4),
        (6, 4, 6, 2),
        (2, 2, 2, 1),
        (5, 5, 5, 1),
        (4, 6, 4, 2),
    ]

    for n, m, k, expected in test_cases:
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        dut.valid_in.value = 1
        
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        
        await wait_for_valid(dut)
        
        result_val = int(dut.result.value)
        
        # If expected is 0xFFFFFFFF (saturation for -1 or overflow), check for saturation
        if expected == 0xFFFFFFFF:
            if result_val != 0xFFFFFFFF:
                 raise TestFailure(f"Case n={n}, m={m}, k={k}: Expected saturation (0xFFFFFFFF), got {result_val}")
        else:
            # For small expected values, check exact match
            if result_val != expected:
                raise TestFailure(f"Case n={n}, m={m}, k={k}: Expected {expected}, got {result_val}")
        
        await RisingEdge(dut.clk) # Small gap between tests

    # Additional random small tests
    for _ in range(10):
        n = random.randint(1, 32)
        m = random.randint(1, 32)
        k = random.randint(1, 64)
        
        # Compute expected in Python (limited to 32-bit result check)
        if k > n + m - 2:
            exp = 0xFFFFFFFF
        else:
            # Calculate using Python integers
            if k < n:
                v1 = (n // (k + 1)) * m
            else:
                v1 = m // (k - n + 2)
            
            if k < m:
                v2 = (m // (k + 1)) * n
            else:
                v2 = n // (k - m + 2)
            
            raw_res = max(v1, v2)
            if raw_res > 0xFFFFFFFF:
                exp = 0xFFFFFFFF
            else:
                exp = raw_res

        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        dut.valid_in.value = 1
        
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        
        await wait_for_valid(dut)
        
        result_val = int(dut.result.value)
        if result_val != exp:
            raise TestFailure(f"Random case n={n}, m={m}, k={k}: Expected {exp}, got {result_val}")