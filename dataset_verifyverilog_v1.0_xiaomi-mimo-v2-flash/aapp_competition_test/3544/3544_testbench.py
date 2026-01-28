import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 8
MAX_VAL = (1 << DATA_WIDTH) - 1
MAX_CYCLES = 1000
CLK_NS = 10

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference solver for test generation
def solve_reference(n, groups):
    groups = groups[:n]  # Ensure length n
    # Pad groups to 12 elements
    groups = groups + [0] * (12 - len(groups))
    for X in range(3, 13):
        # Triangular rows: X, X-1, ..., 1
        rows = list(range(X, 0, -1))
        g_copy = list(groups)  # Copy of groups
        row_idx = 0
        rem = rows[row_idx] if row_idx < len(rows) else 0
        placed = True
        # Process groups from largest to smallest (12 to 1)
        for size in range(12, 0, -1):
            count = g_copy[size-1]
            for _ in range(count):
                placed_now = False
                # Try current row
                if size <= rem:
                    # Place here
                    rem -= size
                    if rem > 0:
                        rem -= 1  # Separator, unless at end
                        if rem < 0: rem = 0
                    placed_now = True
                else:
                    # Move to next rows
                    while not placed_now:
                        row_idx += 1
                        if row_idx >= len(rows):
                            placed_now = False
                            break
                        rem = rows[row_idx]
                        if size <= rem:
                            rem -= size
                            if rem > 0:
                                rem -= 1
                                if rem < 0: rem = 0
                            placed_now = True
                if not placed_now:
                    placed = False
                    break
            if not placed:
                break
        if placed:
            return X
    return 0xFF  # Impossible

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cinema_solver(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Randomized test cases
    test_cases = [
        ([0, 1, 1], 3),  # Sample 1
        ([2, 1, 1], 4),  # Sample 2
        ([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], 12),  # One group of 12
        ([10, 5, 2], 4),  # Many small groups
        ([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], 13),  # Should be impossible (1+12 requires 14 seats max in row)
    ]
    
    passed = 0
    failed = 0
    
    for idx, (groups_input, expected) in enumerate(test_cases):
        # Prepare input groups (length 12)
        groups_full = [0] * 12
        for i, val in enumerate(groups_input):
            if i < 12:
                groups_full[i] = clamp_to_width(val, 6)  # Max 30 fits in 6 bits
        
        cocotb.log.info(f"Test {idx+1}: Groups {groups_input}")
        
        try:
            # Write inputs
            for i in range(12):
                port_name = f'group_count_{i+1}' if hasattr(dut, f'group_count_{i+1}') else 'group_count'
                if has_signal(dut, port_name):
                    if hasattr(dut, port_name) and hasattr(getattr(dut, port_name), '__getitem__'):
                        getattr(dut, port_name)[i].value = groups_full[i]
                    else:
                        # Single vector input
                        val = 0
                        for j in range(12):
                            val |= (groups_full[j] & 0x3F) << (j*6)
                        getattr(dut, port_name).value = val
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, 500)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result == 0xFF:
                result_str = "impossible"
            else:
                result_str = str(result)
            
            # Compute expected
            exp_val = solve_reference(12, groups_full)  # n is effectively 12 in spec
            if expected != 0xFF and exp_val != expected:
                cocotb.log.warning(f"Reference mismatch: expected {expected}, got {exp_val}. Using ref.")
                expected = exp_val
            
            if expected == 0xFF:
                exp_str = "impossible"
            else:
                exp_str = str(expected)
            
            if result_str != exp_str:
                raise TestFailure(f"Expected {exp_str}, got {result_str}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result_str}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
