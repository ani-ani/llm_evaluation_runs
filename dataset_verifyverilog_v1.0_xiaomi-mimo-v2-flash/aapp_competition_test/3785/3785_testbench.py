import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

DATA_WIDTH = 8
GRID_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 10000

def pack_grid(grid):
    """Pack 2D grid into flattened array for HDL"""
    packed = []
    for row in grid:
        for cell in row:
            packed.append(ord(cell))
    return packed

def unpack_grid(packed):
    """Unpack flattened HDL result back to 2D grid"""
    grid = []
    for i in range(0, len(packed), GRID_SIZE):
        row = [chr(v) for v in packed[i:i+GRID_SIZE]]
        grid.append(row)
    return grid

def bfs_count_and_order(grid, n, m):
    """BFS to count empty cells and get traversal order"""
    # Find start
    start_r, start_c = -1, -1
    for r in range(n):
        for c in range(m):
            if grid[r][c] == '.':
                start_r, start_c = r, c
                break
        if start_r != -1:
            break
    
    if start_r == -1:
        return 0, []
    
    visited = [[False]*m for _ in range(n)]
    queue = [(start_r, start_c)]
    visited[start_r][start_c] = True
    order = []
    
    while queue:
        r, c = queue.pop(0)
        order.append((r, c))
        # Neighbors
        for dr, dc in [(1,0), (-1,0), (0,1), (0,-1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < n and 0 <= nc < m and not visited[nr][nc] and grid[nr][nc] == '.':
                visited[nr][nc] = True
                queue.append((nr, nc))
    
    return len(order), order

def create_test_grid(n, m, k):
    """Create a valid test maze"""
    # Use a simple connected grid
    grid = [['#' for _ in range(m)] for _ in range(n)]
    # Create connected area
    for r in range(n):
        for c in range(m):
            if (r + c) % 2 == 0 or (r == 0 and c == 0):
                grid[r][c] = '.'
    # Ensure connectivity
    grid[0][0] = '.'
    # Count empties and adjust k
    empty_count = sum(row.count('.') for row in grid)
    if k >= empty_count:
        k = empty_count - 1
    return grid, k

def create_test_maze_v2(n, m, k):
    """Create a simple connected maze"""
    grid = [['#' for _ in range(m)] for _ in range(n)]
    # Create a simple connected path
    grid[0][0] = '.'
    grid[0][1] = '.'
    grid[1][0] = '.'
    grid[1][1] = '.'
    grid[0][2] = '.' if m > 2 else '#'
    grid[1][2] = '.' if m > 2 else '#'
    if n > 2:
        grid[2][0] = '.'
        grid[2][1] = '.'
    # Fill rest randomly but keep connectivity
    for r in range(n):
        for c in range(m):
            if grid[r][c] == '#':
                # Maybe add some empty cells
                if random.random() > 0.3:
                    grid[r][c] = '.'
    # Count empties
    empty_count = sum(row.count('.') for row in grid)
    if empty_count <= k:
        k = max(0, empty_count - 1)
    return grid, k

def solve_maze(grid, n, m, k):
    """Reference solution in Python"""
    total_empty, order = bfs_count_and_order(grid, n, m)
    result = [row[:] for row in grid]
    # Mark first (total_empty - k) as '.' (connected component)
    # Mark rest as 'X'
    for i, (r, c) in enumerate(order):
        if i < total_empty - k:
            result[r][c] = '.'
        else:
            result[r][c] = 'X'
    return result

def verify_solution(original_grid, result_grid, n, m, k):
    """Verify the solution meets requirements"""
    # Check counts
    x_count = 0
    dot_count = 0
    hash_count = 0
    
    for r in range(n):
        for c in range(m):
            ch = result_grid[r][c]
            if ch == 'X':
                x_count += 1
            elif ch == '.':
                dot_count += 1
            elif ch == '#':
                hash_count += 1
            else:
                raise TestFailure(f"Invalid character at ({r},{c}): {ch}")
    
    if x_count != k:
        raise TestFailure(f"Expected {k} 'X' cells, got {x_count}")
    
    # Check connectivity of '.' cells
    # Find first '.'
    start_r, start_c = -1, -1
    for r in range(n):
        for c in range(m):
            if result_grid[r][c] == '.':
                start_r, start_c = r, c
                break
        if start_r != -1:
            break
    
    if start_r == -1:
        if dot_count == 0:
            return  # No empty cells is OK if k matches
        raise TestFailure("No '.' cells found but dot_count > 0")
    
    # BFS to count reachable '.'
    visited = [[False]*m for _ in range(n)]
    queue = [(start_r, start_c)]
    visited[start_r][start_c] = True
    reachable = 0
    
    while queue:
        r, c = queue.pop(0)
        reachable += 1
        for dr, dc in [(1,0), (-1,0), (0,1), (0,-1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < n and 0 <= nc < m and not visited[nr][nc] and result_grid[nr][nc] == '.':
                visited[nr][nc] = True
                queue.append((nr, nc))
    
    if reachable != dot_count:
        raise TestFailure(f"Connectivity broken: reachable {reachable} '.' cells, but total {dot_count}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maze_connectivity(dut):
    """Test maze connectivity transformation"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(3):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        # (n, m, k, desc)
        (3, 3, 1, "small 3x3"),
        (4, 4, 2, "4x4 moderate"),
        (5, 5, 3, "5x5 larger"),
        (2, 2, 0, "tiny 2x2"),
        (8, 8, 10, "8x8 grid"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, k, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, m={m}, k={k})")
        
        try:
            # Create test input
            grid, actual_k = create_test_maze_v2(n, m, k)
            expected = solve_maze(grid, n, m, actual_k)
            
            # Prepare input data
            flat_grid = pack_grid(grid)
            
            # Write to DUT
            if is_seq:
                # Check if grid_in is array
                if has_signal(dut, 'grid_in'):
                    for idx, val in enumerate(flat_grid):
                        if hasattr(dut.grid_in, '__getitem__'):
                            dut.grid_in[idx].value = clamp_to_width(val, DATA_WIDTH)
                        else:
                            # Packed array
                            pass
                else:
                    # Individual ports: grid_in_0, grid_in_1, ...
                    for idx, val in enumerate(flat_grid):
                        sig_name = f'grid_in_{idx}'
                        if has_signal(dut, sig_name):
                            getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
                
                # Set n, m, k
                if has_signal(dut, 'n'):
                    dut.n.value = n
                if has_signal(dut, 'm'):
                    dut.m.value = m
                if has_signal(dut, 'k'):
                    dut.k.value = actual_k
                
                # Start
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done
                max_cycles = 10000
                done = False
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done'):
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            done = True
                            break
                
                if not done:
                    raise TestFailure(f"Timeout after {max_cycles} cycles")
                
                # Read output
                if has_signal(dut, 'grid_out'):
                    result_flat = []
                    for idx in range(n * GRID_SIZE):
                        if hasattr(dut.grid_out, '__getitem__'):
                            val = safe_int(dut.grid_out[idx].value)
                            result_flat.append(val)
                else:
                    result_flat = []
                    for idx in range(n * GRID_SIZE):
                        sig_name = f'grid_out_{idx}'
                        if has_signal(dut, sig_name):
                            val = safe_int(getattr(dut, sig_name).value)
                            result_flat.append(val)
                
                # Convert to grid
                result_grid = []
                for r in range(n):
                    row = []
                    for c in range(m):
                        idx = r * GRID_SIZE + c
                        if idx < len(result_flat):
                            row.append(chr(result_flat[idx]))
                    result_grid.append(row)
                
                # Verify
                verify_solution(grid, result_grid, n, m, actual_k)
                
            else:
                # Combinational
                if has_signal(dut, 'grid_in'):
                    for idx, val in enumerate(flat_grid):
                        if hasattr(dut.grid_in, '__getitem__'):
                            dut.grid_in[idx].value = clamp_to_width(val, DATA_WIDTH)
                
                if has_signal(dut, 'n'):
                    dut.n.value = n
                if has_signal(dut, 'm'):
                    dut.m.value = m
                if has_signal(dut, 'k'):
                    dut.k.value = actual_k
                
                await Timer(500, units='ns')
                
                # Read output
                if has_signal(dut, 'grid_out'):
                    result_flat = []
                    for idx in range(n * GRID_SIZE):
                        if hasattr(dut.grid_out, '__getitem__'):
                            val = safe_int(dut.grid_out[idx].value)
                            result_flat.append(val)
                else:
                    result_flat = []
                    for idx in range(n * GRID_SIZE):
                        sig_name = f'grid_out_{idx}'
                        if has_signal(dut, sig_name):
                            val = safe_int(getattr(dut, sig_name).value)
                            result_flat.append(val)
                
                # Convert to grid
                result_grid = []
                for r in range(n):
                    row = []
                    for c in range(m):
                        idx = r * GRID_SIZE + c
                        if idx < len(result_flat):
                            row.append(chr(result_flat[idx]))
                    result_grid.append(row)
                
                # Verify
                verify_solution(grid, result_grid, n, m, actual_k)
            
            cocotb.log.info(f"  PASS: {desc}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"\nAll tests passed: {passed}/{len(test_cases)}")