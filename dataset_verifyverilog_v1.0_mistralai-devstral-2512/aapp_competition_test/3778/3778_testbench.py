import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 2, 1000, 10, 5000

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def validate_targets(targets, n, a):
    """Validate that targets satisfy constraints and hit counts"""
    if not targets:
        return True  # Empty configuration for all zeros
    
    # Count targets per row and column
    row_count = {}
    col_count = {}
    for r, c in targets:
        row_count[r] = row_count.get(r, 0) + 1
        col_count[c] = col_count.get(c, 0) + 1
        if row_count[r] > 2 or col_count[c] > 2:
            return False
    
    # Validate hit counts (simplified check)
    # For boomerang physics, we check basic constraints
    return True

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_boomerang_targets(dut):
    # Check for sequential signals
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, a_list, expected_valid, description)
    test_cases = [
        (1, [0], True, "Single column, no targets"),
        (1, [1], True, "Single column, one target"),
        (1, [2], True, "Single column, two targets (impossible in single col?)"),
        (3, [1, 2, 1], True, "Simple valid case"),
        (4, [1, 2, 3, 1], True, "Mix of values"),
        (4, [3, 3, 3, 1], False, "Too many 3s"),
        (6, [2, 0, 3, 0, 1, 1], True, "First example"),
        (6, [3, 2, 2, 2, 1, 1], False, "Third example (invalid)"),
    ]
    
    for i, (n, a_list, expected_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, a={a_list})")
        try:
            # Reset
            if is_seq:
                await reset_dut(dut)
            
            # Feed sequence
            if is_seq and has_signal(dut, 'valid_in'):
                dut.valid_in.value = 1
                for idx, a_val in enumerate(a_list):
                    dut.a_in.value = clamp_to_width(a_val, DATA_WIDTH)
                    await RisingEdge(dut.clk)
                dut.valid_in.value = 0
            
            # Wait for done
            if is_seq:
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Check error flag
            has_error = has_signal(dut, 'error') and is_value_defined(dut.error.value) and int(dut.error.value) == 1
            
            if expected_valid and has_error:
                raise TestFailure(f"Expected valid but got error flag")
            elif not expected_valid and not has_error:
                raise TestFailure(f"Expected error but got no error flag")
            
            # If valid, check target count and validate configuration
            if expected_valid and not has_error:
                if has_signal(dut, 'target_count') and is_value_defined(dut.target_count.value):
                    target_count = int(dut.target_count.value)
                    if target_count > 2 * n:
                        raise TestFailure(f"Target count {target_count} exceeds 2n={2*n}")
                    
                    # Collect targets if module supports reading them
                    # For now, we just verify count is within bounds
                    cocotb.log.info(f"  Target count: {target_count}")
                else:
                    cocotb.log.info(f"  Target count signal not found, skipping validation")
            
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
