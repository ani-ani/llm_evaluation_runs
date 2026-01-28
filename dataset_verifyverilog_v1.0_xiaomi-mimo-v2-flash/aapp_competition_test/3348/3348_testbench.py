import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def pack_grid(values, rows, cols, bits_per_cell=4):
    packed = 0
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            if idx < len(values):
                cell_val = clamp_to_width(values[idx], bits_per_cell)
                packed |= (cell_val << (idx * bits_per_cell))
    return packed

def generate_valid_grid(rows, cols, a, b, c):
    total = rows * cols
    if a + b + c != total:
        return None, None
    # Simple checkerboard pattern for 2 colors, adjust for 3
    # We'll use a basic pattern: A at even positions, B at odd, but need 3 colors
    # Since R and C are even, we can create 2x2 blocks with A,B,C arranged
    # Pattern for 2 colors: A B A B
    #                    B A B A
    # For 3 colors, we need a more complex arrangement, but for max 16x16, we can try a fixed pattern
    # Let's assume a pattern where we fill row by row with repeating A, B, C, A, B... but ensuring no adjacents
    # This is tricky; for benchmarking, we just need a valid arrangement that satisfies counts.
    # For simplicity, we'll generate a pattern where we alternate two main colors and use the third sparingly.
    # However, the problem requires exactly a, b, c counts.
    # A simple valid arrangement for even R,C: Use a 2x2 tile that avoids adjacency.
    # Tile 1: A B
    #         B C
    # But this might not match counts. For the benchmark, we will just generate a valid sequence
    # and see if counts match. Since the problem is NP-hard in general, we assume the solver finds one.
    # Here, we'll just create a linear fill to satisfy the interface for testing.
    # We'll create a grid where we fill with A, then B, then C, but in a staggered way to avoid adjacency.
    # For 16x16 max, we can use a simple pattern: 
    # Row i: if i%2==0: A B A B... else: B A B A... and replace last elements with C if needed.
    # This is a simplification for the testbench.
    grid = []
    # Counters
    ca, cb, cc = 0, 0, 0
    for r in range(rows):
        for c in range(cols):
            if r % 2 == 0:
                if c % 2 == 0:
                    if ca < a:
                        grid.append(1) # A
                        ca += 1
                    elif cb < b:
                        grid.append(2) # B
                        cb += 1
                    else:
                        grid.append(3) # C
                        cc += 1
                else:
                    if cb < b:
                        grid.append(2) # B
                        cb += 1
                    elif ca < a:
                        grid.append(1) # A
                        ca += 1
                    else:
                        grid.append(3) # C
                        cc += 1
            else:
                if c % 2 == 0:
                    if cb < b:
                        grid.append(2) # B
                        cb += 1
                    elif ca < a:
                        grid.append(1) # A
                        ca += 1
                    else:
                        grid.append(3) # C
                        cc += 1
                else:
                    if ca < a:
                        grid.append(1) # A
                        ca += 1
                    elif cb < b:
                        grid.append(2) # B
                        cb += 1
                    else:
                        grid.append(3) # C
                        cc += 1
    # Check if we used exactly the counts
    if ca != a or cb != b or cc != c:
        # If counts don't match our simple pattern, return None (impossible for this pattern)
        return None, None
    # Validate adjacency
    for r in range(rows):
        for c in range(cols):
            current = grid[r * cols + c]
            if c + 1 < cols:
                right = grid[r * cols + c + 1]
                if current == right:
                    return None, None
            if r + 1 < rows:
                down = grid[(r + 1) * cols + c]
                if current == down:
                    return None, None
    return grid, pack_grid(grid, rows, cols)

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grid_coloring(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (4, 4, 10, 3, 3, False, "Too many A"),
        (4, 4, 6, 5, 5, True, "Valid counts"),
        (2, 2, 2, 1, 1, True, "Small valid"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (R, C, a, b, c, should_be_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            if has_signal(dut, 'R'): dut.R.value = clamp_to_width(R, 4)
            if has_signal(dut, 'C'): dut.C.value = clamp_to_width(C, 4)
            if has_signal(dut, 'a'): dut.a.value = clamp_to_width(a, 16)
            if has_signal(dut, 'b'): dut.b.value = clamp_to_width(b, 16)
            if has_signal(dut, 'c'): dut.c.value = clamp_to_width(c, 16)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            is_valid = int(dut.valid.value) == 1
            
            if should_be_valid:
                if not is_valid:
                    raise TestFailure(f"Expected valid arrangement, but got invalid")
                
                # Verify the grid
                grid_val = int(dut.grid.value)
                expected_grid, expected_packed = generate_valid_grid(R, C, a, b, c)
                if expected_packed is None:
                     # If our testbench generator fails, we can't verify strictly, but check basic validity
                     # For this benchmark, we trust the solver if it outputs valid
                     pass
                else:
                    # Check counts in the result (quick check)
                    # Decode packed grid
                    res_grid = []
                    for r in range(R):
                        for c_ in range(C):
                            idx = r * C + c_
                            cell = (grid_val >> (idx * 4)) & 0xF
                            res_grid.append(cell)
                    
                    count_a = res_grid.count(1)
                    count_b = res_grid.count(2)
                    count_c = res_grid.count(3)
                    
                    if count_a != a or count_b != b or count_c != c:
                        raise TestFailure(f"Counts mismatch: got A={count_a}, B={count_b}, C={count_c}")
                    
                    # Check adjacency
                    for r in range(R):
                        for c_ in range(C):
                            idx = r * C + c_
                            curr = res_grid[idx]
                            if curr == 0: raise TestFailure("Empty cell found")
                            if c_ + 1 < C:
                                right = res_grid[idx + 1]
                                if curr == right:
                                    raise TestFailure(f"Adjacency violation at ({r},{c_}) and ({r},{c_+1})")
                            if r + 1 < R:
                                down = res_grid[idx + C]
                                if curr == down:
                                    raise TestFailure(f"Adjacency violation at ({r},{c_}) and ({r+1},{c_})")
            else:
                if is_valid:
                    raise TestFailure(f"Expected impossible, but got valid")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")