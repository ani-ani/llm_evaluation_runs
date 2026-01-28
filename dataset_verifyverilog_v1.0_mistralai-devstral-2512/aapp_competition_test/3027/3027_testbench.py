import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 1
MAX_DIM = 16
CLK_NS = 10
MAX_CYCLES = 5000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def python_solver(grid_str):
    lines = grid_str.strip().split('\n')
    n, m = map(int, lines[0].split())
    grid = [list(l.strip()) for l in lines[1:n+1]]
    
    h, w = n, m
    # Create integer bitmask for grid
    grid_mask = 0
    for r in range(h):
        for c in range(w):
            if grid[r][c] == '#':
                grid_mask |= (1 << ((h-1-r)*w + (w-1-c)))
    
    min_nubs = h * w + 1
    
    # Iterate offsets
    # dy from -(h-1) to (h-1)
    # dx from -(w-1) to (w-1)
    
    for dy in range(-(h-1), h):
        for dx in range(-(w-1), w):
            if dx == 0 and dy == 0: continue
            
            # Construct candidate stamp S
            # S = Grid AND (Grid shifted by (-dy, -dx))
            # In bit ops: shift grid by offset
            
            shift_bits = dy * w + dx
            shifted_grid = 0
            
            # Perform shift
            if shift_bits >= 0:
                shifted_grid = (grid_mask >> shift_bits)
            else:
                shifted_grid = (grid_mask << (-shift_bits))
            
            # Mask to ensure we don't wrap around or overflow bits incorrectly for the check
            # However, we need to be careful about boundaries.
            # The logical check is per-cell.
            # We can simply compute S bits where both Grid and Shifted are 1.
            # But we must ensure the shift didn't cross row boundaries in a way that wraps (conceptually).
            # In a bit-shifted integer, bits moving between rows is correct for 2D shift if rows are packed.
            # However, we must mask out bits that shifted OUT of the valid rectangle.
            
            # Reconstruct valid mask for the grid
            valid_mask = 0
            for r in range(h):
                for c in range(w):
                    valid_mask |= (1 << ((h-1-r)*w + (w-1-c)))
            
            # Shifted grid must be masked with valid_mask to simulate boundaries (zeros outside)
            shifted_grid &= valid_mask
            
            # Candidate S
            s_mask = grid_mask & shifted_grid
            
            # Now verify: does S union (S shifted by (dy, dx)) equal Grid?
            # S shifted is s_mask shifted by (dy, dx) -> which is exactly shifted_grid (since shifted_grid was Grid shifted by (-dy, -dx)?
            # Wait. shifted_grid = Grid >> (dy*w + dx) if dy>=0.
            # We want S_shifted = S shifted by (dy, dx).
            # S = Grid & ShiftedGrid
            # S_shifted = (Grid & ShiftedGrid) shifted by (dy, dx)
            # This is tricky. Let's stick to the definition:
            # We define S as the 'intersection' of the two stamps.
            # Stamp 1 is at (0,0). Stamp 2 is at (dy, dx).
            # Result is Stamp1 | Stamp2.
            # We want Result == Grid.
            # We want to minimize |Stamp1| (which equals |Stamp2| since they are same shape).
            # Stamp1 must be subset of Grid.
            # Stamp2 must be subset of Grid.
            # Stamp1 | Stamp2 = Grid.
            # Let's try constructing Stamp1 as the area covered by Grid that is NOT covered by Stamp2 shifted back.
            # Actually, the minimal stamp for a fixed offset is simply the intersection of Grid and Grid shifted by (-dy, -dx).
            # Let's check this logic with a small example.
            # Grid: 1 1 .
            #       . 1 1
            # Offset (0, 1). 
            # Stamp 1 covers (0,0)-(0,1). Stamp 2 covers (0,1)-(0,2).
            # Union is Grid.
            # Grid shifted by (0, -1) (i.e. right shift in bits if rows are packed left-to-right):
            # . 1 1  (Top row shifted right)
            # 1 1 .  (Bot row shifted right)
            # Intersection of Grid and ShiftedGrid:
            # . 1 .
            # . 1 .
            # This is 2 bits. Is this the stamp? No, the stamp is 2 bits wide.
            # Wait, the stamp is defined by the pattern.
            # If Stamp1 is at (0,0), it covers cells (r, c) such that S[r][c] is 1.
            # Stamp2 is at (0,1), it covers (r, c+1).
            # Union covers (r, c) if S[r][c] or S[r][c-1] is 1.
            # We need S such that for all (r,c) in Grid: S[r][c] | S[r][c-1] == 1 (if Grid[r][c]==1)
            # And S[r][c] | S[r][c-1] == 0 (if Grid[r][c]==0)
            # This is a covering problem.
            
            # Let's use the brute force 16x16 check per offset which is fast enough for Python but needs Verilog logic.
            # Verilog Logic: 
            # 1. Compute candidate S = Grid & (Grid shifted by (-dy, -dx)).
            # 2. Compute Union = S | (S shifted by (dy, dx)).
            # 3. If Union == Grid, it's a candidate.
            # 4. Check popcount of S.
            
            # Recompute S properly for bit logic:
            # Shift Grid by (-dy, -dx) means bits move towards lower indices (right shift if row-major big-endian?)
            # Let's stick to Python simulation to verify.
            
            # Python simulation of shift:
            def shift_grid(g, dr, dc, H, W):
                res = 0
                for r in range(H):
                    for c in range(W):
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < H and 0 <= nc < W:
                            if (g >> ((H-1-r)*W + (W-1-c))) & 1:
                                res |= (1 << ((H-1-nr)*W + (W-1-nc)))
                return res

            s_shifted_back = shift_grid(grid_mask, -dy, -dx, h, w)
            s_candidate = grid_mask & s_shifted_back
            
            s_shifted_fwd = shift_grid(s_candidate, dy, dx, h, w)
            
            if s_shifted_fwd == grid_mask:
                # Valid solution
                # Count bits in s_candidate
                cnt = bin(s_candidate).count('1')
                if cnt < min_nubs:
                    min_nubs = cnt
    
    return min_nubs

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_bureaucracy(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        ("4 8\n..#..#..\n.######.\n.######.\n..#..#..", 8),
        ("3 3\n...\n.#.\n...", 1),
        ("2 6\n.#####\n#####.", 5),
        ("2 5\n.#.#.\n#.#.#", 3)
    ]

    for i, (inp_str, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}")
        
        # Parse Input
        lines = inp_str.strip().split('\n')
        h, w = map(int, lines[0].split())
        grid = [list(l.strip()) for l in lines[1:h+1]]
        
        # Pack grid into 256-bit integer (row-major, top-left is MSB?)
        # Let's say Row 0 is MSB, Col 0 is MSB of row
        grid_mask = 0
        for r in range(h):
            for c in range(w):
                if grid[r][c] == '#':
                    bit_idx = (r * 16) + c
                    grid_mask |= (1 << (255 - bit_idx))
        
        # Send inputs
        dut.height.value = h
        dut.width.value = w
        
        # Assign grid bit by bit (Verilog array access simulation)
        # dut.grid_in is a 256-bit vector
        dut.grid_in.value = grid_mask
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
             raise TestFailure(f"Test {i+1} Failed: Expected {expected}, Got {result}")
        else:
             dut._log.info(f"Test {i+1} Passed: {result}")
