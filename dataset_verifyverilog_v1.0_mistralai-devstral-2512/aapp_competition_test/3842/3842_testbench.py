import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 32
FRAC_BITS = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return int(v) & mask

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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
async def test_freelancer(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Helper to calculate expected value in Python
    def solve_py(n, p, q, projects):
        min_days = float('inf')
        
        # Single project
        for i in range(n):
            a_i, b_i = projects[i]
            if a_i > 0 and b_i > 0:
                days = max(p / a_i, q / b_i)
                min_days = min(min_days, days)
        
        # Mixed projects
        for i in range(n):
            for j in range(i + 1, n):
                a1, b1 = projects[i]
                a2, b2 = projects[j]
                den = a1 * b2 - b1 * a2
                if den != 0:
                    t1 = (p * b2 - q * a2) / den
                    t2 = (q * a1 - p * b1) / den
                    if t1 >= 0 and t2 >= 0:
                        min_days = min(min_days, t1 + t2)
        return min_days

    # Test cases: (n, p, q, projects, description)
    test_cases = [
        (3, 20, 20, [(6, 2), (1, 3), (2, 6)], "Example 1"),
        (4, 1, 1, [(2, 3), (3, 2), (2, 3), (3, 2)], "Example 2"),
        (1, 4, 6, [(2, 3)], "Single Project 1"),
        (2, 5, 8, [(2, 4), (5, 2)], "Pair 1"),
        (2, 4, 8, [(2, 4), (5, 2)], "Pair 2"),
    ]

    passed = 0
    failed = 0

    for tc_idx, (n, p_val, q_val, projects, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}: {desc}")
        try:
            # Prepare inputs
            p_fixed = float_to_fixed(p_val)
            q_fixed = float_to_fixed(q_val)
            
            # Pad projects to 6
            padded_projects = projects + [(0, 0)] * (6 - n)
            
            # Assign to DUT
            dut.p.value = clamp_to_width(p_fixed, DATA_WIDTH)
            dut.q.value = clamp_to_width(q_fixed, DATA_WIDTH)
            
            for i in range(6):
                a_i, b_i = padded_projects[i]
                a_fixed = float_to_fixed(a_i)
                b_fixed = float_to_fixed(b_i)
                getattr(dut, f'a_{i}').value = clamp_to_width(a_fixed, DATA_WIDTH)
                getattr(dut, f'b_{i}').value = clamp_to_width(b_fixed, DATA_WIDTH)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            hw_result = fixed_to_float(int(dut.result.value))
            
            # Calculate expected
            expected = solve_py(n, p_val, q_val, projects)
            
            # Check tolerance
            # Relative error: |hw - exp| / max(1, exp) <= 1e-6
            error = abs(hw_result - expected)
            rel_err = error / max(1.0, expected)
            
            if rel_err > 1e-6:
                raise TestFailure(f"Result mismatch: HW={hw_result:.10f}, Py={expected:.10f}, RelErr={rel_err:.2e}")
            
            cocotb.log.info(f"PASS: {hw_result:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
