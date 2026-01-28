import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for scaling
MAX_LAMPS = 16
MAX_COORD = 8
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 5000

# Helper functions

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

def pack_lamp_coords(rows, cols, coord_bits=4):
    """Pack lamp coordinates into expected port structure"""
    # Individual ports expected: lamp_row[i], lamp_col[i]
    pass

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

# Test case generators

def generate_test_case(n, r, lamp_positions):
    """Generate test input for Python verification"""
    k = len(lamp_positions)
    lines = [f"{n} {r} {k}"]
    for row, col in lamp_positions:
        lines.append(f"{row} {col}")
    return "\n".join(lines) + "\n"

def solve_python(n, r, lamps):
    """Python solver for reference - returns 1 or 0"""
    k = len(lamps)
    if k == 0:
        return 1
    
    # Build constraints for 2-SAT
    # For each lamp i: choice 0=light row, 1=light column
    # Constraints: for any square (x,y) that multiple lamps can reach:
    # - In row x: at most one lamp chooses row-mode
    # - In column y: at most one lamp chooses column-mode
    
    from collections import defaultdict
    
    # Map each potential illuminated square to lamps that can illuminate it
    row_conflicts = defaultdict(set)  # row -> lamps that can illuminate squares in this row
    col_conflicts = defaultdict(set)  # col -> lamps that can illuminate squares in this col
    
    lamp_r = lamps[0][0] - 1 if lamps else 0
    lamp_c = lamps[0][1] - 1 if lamps else 0
    
    # Check conflicts
    # For each pair of lamps
    for i in range(k):
        ri, ci = lamps[i][0] - 1, lamps[i][1] - 1
        for j in range(i + 1, k):
            rj, cj = lamps[j][0] - 1, lamps[j][1] - 1
            
            # Can they conflict in row mode?
            # Lamp i row-mode illuminates row ri, columns [ci-r, ci+r]
            # Lamp j row-mode illuminates row rj, columns [cj-r, cj+r]
            if ri == rj:  # Same row
                cols_i = set(range(ci - r, ci + r + 1))
                cols_j = set(range(cj - r, cj + r + 1))
                if cols_i & cols_j:  # Overlap
                    # Constraint: not (i row AND j row)
                    pass
            
            # Can they conflict in column mode?
            if ci == cj:  # Same column
                rows_i = set(range(ri - r, ri + r + 1))
                rows_j = set(range(rj - r, rj + r + 1))
                if rows_i & rows_j:
                    # Constraint: not (i col AND j col)
                    pass
            
            # Cross conflicts: i row-mode vs j col-mode
            # If lamp i illuminates row ri, and lamp j illuminates col cj
            # They might illuminate square (ri, cj) if it's within reach of both
            # But this is allowed! Problem only says at most one per row AND at most one per column
            # This means row-mode and col-mode can co-exist for same square
            
    # Actually, the constraint is simpler:
    # For each row r, at most ONE lamp can be in row-mode and have r in its range
    # For each col c, at most ONE lamp can be in col-mode and have c in its range
    
    # This is a hitting set / assignment problem
    # We can try all 2^k assignments
    
    for mask in range(1 << k):
        # mask bit i: 0=row-mode, 1=col-mode
        valid = True
        
        # Check row constraints
        row_lamps = {}  # row -> lamp index that uses row-mode for this row
        for i in range(k):
            if (mask >> i) & 1 == 0:  # row-mode
                ri = lamps[i][0] - 1
                for r in range(ri - r, ri + r + 1):
                    if 0 <= r < n:
                        if r in row_lamps:
                            valid = False
                            break
                        row_lamps[r] = i
                if not valid:
                    break
        if not valid:
            continue
        
        # Check column constraints
        col_lamps = {}  # col -> lamp index that uses col-mode for this col
        for i in range(k):
            if (mask >> i) & 1 == 1:  # col-mode
                ci = lamps[i][1] - 1
                for c in range(ci - r, ci + r + 1):
                    if 0 <= c < n:
                        if c in col_lamps:
                            valid = False
                            break
                        col_lamps[c] = i
                if not valid:
                    break
        
        if valid:
            return 1
    
    return 0

def scale_lamps_for_verilog(lamps, n):
    """Scale coordinates to fit in 4-bit (0-7)"""
    scaled = []
    for (r, c) in lamps:
        # Map 1-indexed to 0-indexed, scale to fit in 4 bits
        sr = clamp_to_width(r - 1, 4)
        sc = clamp_to_width(c - 1, 4)
        scaled.append((sr, sc))
    return scaled

def scale_params_for_verilog(n, r, k):
    """Scale parameters for Verilog constraints"""
    # n: 1-8, r: 0-7, k: 0-15
    sn = clamp_to_width(min(n, 8), 4)
    sr = clamp_to_width(min(r, 7), 4)
    sk = clamp_to_width(min(k, 15), 4)
    return sn, sr, sk

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lamp_lighting(dut):
    """Test the lamp lighting module"""
    
    # Check for required signals
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_result = has_signal(dut, 'result')
    
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, r, lamps)
    test_cases = [
        # Example 1: 3x3 grid, reach 2, 5 lamps - should be possible
        (3, 2, [(1,1), (1,3), (3,1), (3,3), (2,2)], 1, "3x3 reach2 5 lamps"),
        # Example 2: 3x3 grid, reach 2, 6 lamps - should be impossible
        (3, 2, [(1,1), (1,2), (1,3), (3,1), (3,2), (3,3)], 0, "3x3 reach2 6 lamps"),
        # Edge case: 1 lamp
        (1, 0, [(1,1)], 1, "1x1 reach0 1 lamp"),
        # Edge case: no lamps
        (1, 0, [], 1, "no lamps"),
        # Conflict in same row
        (3, 1, [(2,1), (2,3)], 1, "2 lamps same row reach1"),
        # Too many lamps in same row with reach
        (4, 2, [(2,1), (2,2), (2,3)], 0, "3 lamps same row conflict"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, r, lamps, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        cocotb.log.info(f"  Grid {n}x{n}, reach {r}, {len(lamps)} lamps")
        
        try:
            # Scale parameters
            sn, sr, sk = scale_params_for_verilog(n, r, len(lamps))
            scaled_lamps = scale_lamps_for_verilog(lamps, n)
            
            # Set inputs
            if has_signal(dut, 'grid_size'):
                dut.grid_size.value = sn
            if has_signal(dut, 'max_reach'):
                dut.max_reach.value = sr
            if has_signal(dut, 'num_lamps'):
                dut.num_lamps.value = sk
            
            # Set lamp coordinates
            for i in range(MAX_LAMPS):
                row_port_name = f'lamp_row_{i}' if has_signal(dut, f'lamp_row_{i}') else 'lamp_row'
                col_port_name = f'lamp_col_{i}' if has_signal(dut, f'lamp_col_{i}') else 'lamp_col'
                
                if i < len(scaled_lamps):
                    r_val, c_val = scaled_lamps[i]
                    if has_signal(dut, row_port_name):
                        getattr(dut, row_port_name).value = r_val
                    elif has_signal(dut, 'lamp_row') and hasattr(dut.lamp_row, '__getitem__'):
                        dut.lamp_row[i].value = r_val
                    
                    if has_signal(dut, col_port_name):
                        getattr(dut, col_port_name).value = c_val
                    elif has_signal(dut, 'lamp_col') and hasattr(dut.lamp_col, '__getitem__'):
                        dut.lamp_col[i].value = c_val
                else:
                    # Set unused lamps to 0
                    if has_signal(dut, row_port_name):
                        getattr(dut, row_port_name).value = 0
                    elif has_signal(dut, 'lamp_row') and hasattr(dut.lamp_row, '__getitem__'):
                        dut.lamp_row[i].value = 0
                    
                    if has_signal(dut, col_port_name):
                        getattr(dut, col_port_name).value = 0
                    elif has_signal(dut, 'lamp_col') and hasattr(dut.lamp_col, '__getitem__'):
                        dut.lamp_col[i].value = 0
            
            # Verify Python solver matches expectation
            python_result = solve_python(n, r, lamps)
            if python_result != expected:
                cocotb.log.error(f"  Python solver mismatch: expected {expected}, got {python_result}")
            
            # Start computation
            if has_start:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational circuit
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Result: {result}, Expected: {expected}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")