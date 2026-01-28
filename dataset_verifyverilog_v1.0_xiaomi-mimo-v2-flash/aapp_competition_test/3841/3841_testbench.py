import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def python_solve(p, k):
    coeffs = []
    while p != 0:
        rem = p % k
        p = p // k
        if rem < 0:
            rem += k
            p += 1
        coeffs.append(rem)
    if not coeffs:
        coeffs = [0]
    return coeffs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_poly_mod(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (46, 2),
        (2018, 214),
        (4, 2),
        (5, 2),
        (10, 3),
        (250, 1958),
        (1000000000000000000, 2000),
        (1, 2),
        (2, 2),
        (3, 2),
        (6, 2),
        (7, 2),
        (8, 2),
        (9, 2),
        (10, 2),
        (1, 3),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (6, 3),
        (7, 3),
        (8, 3),
        (9, 3),
    ]

    passed = 0
    failed = 0

    for i, (p_val, k_val) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: p={p_val}, k={k_val}")
        try:
            # Set inputs
            dut.p.value = p_val
            dut.k.value = k_val
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check error flag
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    # Check if python expects -1? No, python always finds a solution for k>=2.
                    # So if HDL errors, it's a bug.
                    raise TestFailure(f"HDL reported error for valid input p={p_val}, k={k_val}")
            
            # Get result length
            len_val = safe_int(dut.len.value)
            if len_val == 0:
                 # Should not happen for non-zero p, but handle
                 if p_val == 0:
                     pass # acceptable
                 else:
                     raise TestFailure(f"Length is 0 for non-zero p")
            
            # Get coefficients
            result_coeffs = []
            for j in range(len_val):
                # Assuming array access dut.coeff[j]
                if has_signal(dut, f'coeff_{j}'):
                    v = int(getattr(dut, f'coeff_{j}').value)
                else:
                    v = int(dut.coeff[j].value)
                result_coeffs.append(v)
            
            # Compare with Python
            expected = python_solve(p_val, k_val)
            
            if result_coeffs != expected:
                 raise TestFailure(f"Mismatch. Expected {expected}, got {result_coeffs}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
