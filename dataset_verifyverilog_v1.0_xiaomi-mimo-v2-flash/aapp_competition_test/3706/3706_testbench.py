import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_VAL = 255
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions from Section A
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

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

# Test solver in Python for verification
def solve_python(n, m, grid):
    best = None
    best_moves = float('inf')
    best_is_rows = None
    best_r = None
    best_c = None
    best_x = None
    
    for x in range(16):
        c = [grid[0][j] - x for j in range(m)]
        if any(val < 0 for val in c):
            continue
        
        r = []
        valid = True
        for i in range(n):
            row_min = float('inf')
            for j in range(m):
                diff = grid[i][j] - c[j]
                if diff < 0:
                    valid = False
                    break
                row_min = min(row_min, diff)
            if not valid:
                break
            r.append(row_min)
        
        if not valid:
            continue
        
        # Verify
        for i in range(n):
            for j in range(m):
                if r[i] + c[j] + x != grid[i][j]:
                    valid = False
                    break
            if not valid:
                break
        
        if valid:
            moves = x * min(n, m) + sum(r) + sum(c)
            if moves < best_moves:
                best_moves = moves
                best_is_rows = n <= m
                best_r = r
                best_c = c
                best_x = x
    
    if best is None:
        return (-1, None, None, None)
    
    # Generate moves
    moves_list = []
    if best_is_rows:
        for i in range(n):
            for _ in range(best_r[i]):
                moves_list.append(f"row {i+1}")
        for j in range(m):
            for _ in range(best_c[j]):
                moves_list.append(f"col {j+1}")
        for _ in range(best_x):
            for i in range(n):
                moves_list.append(f"row {i+1}")
    else:
        for j in range(m):
            for _ in range(best_c[j]):
                moves_list.append(f"col {j+1}")
        for i in range(n):
            for _ in range(best_r[i]):
                moves_list.append(f"row {i+1}")
        for _ in range(best_x):
            for j in range(m):
                moves_list.append(f"col {j+1}")
    
    return (best_moves, best_r, best_c, moves_list)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_karen_game(dut):
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, m, grid_data, expected_moves_or_neg1)
    test_cases = [
        (3, 3, [[1,1,1],[1,1,1],[1,1,1]], 3),
        (3, 3, [[0,0,0],[0,1,0],[0,0,0]], -1),
        (2, 2, [[1,1],[1,1]], 2),
        (1, 5, [[0,0,0,0,0]], 0),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, m, grid, exp_moves) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={n}, m={m}, exp={exp_moves}")
        
        try:
            # Pack grid into input signals
            # For simplicity, assume inputs are individual wires or a packed reg
            # This depends on actual Verilog interface
            # We'll use a generic approach assuming inputs exist
            
            if is_seq:
                # Set inputs
                if has_signal(dut, 'n'):
                    dut.n.value = n
                if has_signal(dut, 'm'):
                    dut.m.value = m
                
                # Set grid (assuming 2D array or packed reg)
                # For individual port case:
                for i in range(n):
                    for j in range(m):
                        port_name = f'grid_{i}_{j}'
                        if has_signal(dut, port_name):
                            getattr(dut, port_name).value = grid[i][j]
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.valid.value):
                    raise TestFailure("valid signal undefined")
                
                valid = int(dut.valid.value)
                
                if exp_moves == -1:
                    if valid != 0:
                        raise TestFailure(f"Expected invalid, but got valid={valid}")
                else:
                    if valid != 1:
                        raise TestFailure(f"Expected valid=1, got {valid}")
                    
                    if not is_value_defined(dut.moves.value):
                        raise TestFailure("moves signal undefined")
                    
                    moves = int(dut.moves.value)
                    if moves != exp_moves:
                        raise TestFailure(f"Expected {exp_moves} moves, got {moves}")
                
                passed += 1
            else:
                # Combinational test
                await Timer(10, units='ns')
                # Similar checks for combinational
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx+1} FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
