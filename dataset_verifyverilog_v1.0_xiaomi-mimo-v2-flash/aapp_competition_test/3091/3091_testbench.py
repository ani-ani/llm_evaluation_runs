import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

DATA_WIDTH = 8
MAX_N = 9
MAX_M = 10
CLK_NS = 10
MAX_CYCLES = 15000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

# Python reference solver for validation
def count_kenken_section(n, m, t, op, cells):
    # cells: list of (r,c) tuples (0-based)
    count = 0
    # Check if subtraction/division require exactly 2 cells
    if op in ['-', '/'] and m != 2:
        return 0
    
    # Generate all permutations of 1..n of length m
    for perm in itertools.permutations(range(1, n+1), m):
        # Row uniqueness check
        rows = [r for r,c in cells]
        if len(set(rows)) != len(rows):
            continue
        
        # Column uniqueness check
        cols = [c for r,c in cells]
        if len(set(cols)) != len(cols):
            continue
        
        # Arithmetic check
        valid = False
        if op == '+':
            if sum(perm) == t:
                valid = True
        elif op == '-':
            if abs(perm[0] - perm[1]) == t:
                valid = True
        elif op == '*':
            prod = 1
            for v in perm:
                prod *= v
                if prod > t:  # Early break
                    break
            else:
                if prod == t:
                    valid = True
        elif op == '/':
            a, b = perm[0], perm[1]
            if b != 0 and a % b == 0 and a // b == t:
                valid = True
            elif a != 0 and b % a == 0 and b // a == t:
                valid = True
        
        if valid:
            count += 1
    
    return count

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_kenken_section(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        {
            'name': '8x8, 2 cells, 7, subtract',
            'n': 8, 'm': 2, 't': 7, 'op': '-',
            'cells': [(0,0), (0,1)],
            'expected': 2
        },
        {
            'name': '9x9, 2 cells, 7, subtract',
            'n': 9, 'm': 2, 't': 7, 'op': '-',
            'cells': [(0,0), (0,1)],
            'expected': 4
        },
        {
            'name': '8x8, 3 cells, 6, add',
            'n': 8, 'm': 3, 't': 6, 'op': '+',
            'cells': [(4,1), (5,1), (4,0)],
            'expected': 7
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {tc['name']}")
        
        # Calculate expected using Python solver
        expected = count_kenken_section(
            tc['n'], tc['m'], tc['t'], tc['op'], tc['cells']
        )
        
        # Assign inputs
        dut.n.value = tc['n']
        dut.m.value = tc['m']
        dut.t.value = tc['t']
        
        op_ascii = ord(tc['op'])
        dut.op.value = op_ascii
        
        # Assign cell coordinates
        for i_cell in range(MAX_M):
            if i_cell < len(tc['cells']):
                r, c = tc['cells'][i_cell]
                dut.row[i_cell].value = r
                dut.col[i_cell].value = c
            else:
                # Pad with zeros
                dut.row[i_cell].value = 0
                dut.col[i_cell].value = 0
        
        # Start computation
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: Result undefined for {tc['name']}")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"FAIL: {tc['name']} - Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: {tc['name']} - Result {result}")
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")