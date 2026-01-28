import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers from template
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if hasattr(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if hasattr(dut, 'clk'):
            await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if hasattr(dut, 'clk'):
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_integer_division(dut):
    CLK_NS = 10
    DATA_WIDTH = 16
    
    # Setup clock if present
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design - just apply inputs
        await Timer(10, units='ns')
    
    # Test cases: (n, m, expected_q)
    test_cases = [
        (10, 3, 3),
        (4, 2, 2),
        (20, 5, 4),
        (15, 3, 5),
        (0, 5, 0),
        (100, 10, 10),
        (0, 0, 0),  # Division by zero
        (65535, 1, 65535), # Max n / 1
        (65535, 65535, 1), # Max / Max
        (32768, 2, 16384), # Power of two
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, exp_q) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, m={m} -> expected q={exp_q}")
        
        try:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, DATA_WIDTH)
            if has_signal(dut, 'm'):
                dut.m.value = clamp_to_width(m, DATA_WIDTH)
            
            if is_seq:
                # Trigger calculation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut)
                else:
                    await Timer(100, units='ns')
            else:
                # Combinational: wait for propagation
                await Timer(50, units='ns')
            
            # Read result
            q_val = 0
            r_val = 0
            if has_signal(dut, 'q'):
                q_val = int(dut.q.value)
            
            if has_signal(dut, 'r'):
                r_val = int(dut.r.value)
            
            if not is_value_defined(dut.q.value):
                raise TestFailure(f"Quotient undefined for n={n}, m={m}")
            
            # Verify quotient
            if q_val != exp_q:
                raise TestFailure(f"Expected quotient {exp_q}, got {q_val} for n={n}, m={m}")
            
            # Verify remainder logic (if m > 0, n == q*m + r and r < m)
            if m > 0:
                if (q_val * m + r_val) != n:
                    raise TestFailure(f"Remainder mismatch: {q_val}*{m} + {r_val} != {n}")
                if r_val >= m:
                    raise TestFailure(f"Remainder {r_val} >= divisor {m}")
            else:
                # For division by zero, quotient should be 0 per spec
                if q_val != 0:
                    raise TestFailure(f"Quotient for division by zero should be 0, got {q_val}")
            
            cocotb.log.info(f"PASS: q={q_val}, r={r_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(20, units='ns')
    
    cocotb.log.info(f"Results: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
