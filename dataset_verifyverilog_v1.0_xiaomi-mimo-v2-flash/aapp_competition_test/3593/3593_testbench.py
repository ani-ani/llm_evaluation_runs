import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import numpy as np

DATA_WIDTH = 8
ROW_COUNT = 8
COL_COUNT = 3
MAX_K = 16
CLK_NS = 10
MAX_CYCLES = 10000

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
    # Handle signed clamp for simulation logic if needed, but here just range
    if v < 0:
        return v + (1 << bits)
    return min((1 << bits) - 1, v)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference solver for verification
def solve_python(board, K):
    N = len(board)
    INF = -10**9
    # dp[k][mask] where mask is covered by vertical domino from prev row
    # mask 3 bits: 0,1,2
    dp = [[INF]*8 for _ in range(K+1)]
    dp[0][0] = 0
    
    for r in range(N):
        new_dp = [[INF]*8 for _ in range(K+1)]
        # Precompute all horizontal placements for each free mask
        # free_mask is bits that are NOT covered by prev_mask
        for prev_k in range(K+1):
            for prev_mask in range(8):
                if dp[prev_k][prev_mask] == INF: continue
                
                # Cells covered by vertical domino from previous row
                covered_prev = prev_mask
                
                # Try all curr_mask (vertical dominoes starting here)
                for curr_mask in range(8):
                    # Check overlap: curr_mask and covered_prev must be disjoint
                    if curr_mask & covered_prev: continue
                    
                    # Calculate free cells in this row
                    # covered_prev bits are already taken
                    # curr_mask bits are taken by vertical starting here
                    row_used = covered_prev | curr_mask
                    
                    # Now try horizontal dominoes on remaining free cells
                    # 3 cells: 0,1,2. Horizontal pairs: (0,1), (1,2)
                    # We can iterate over placements of horizontal dominoes
                    
                    # Generate all valid horizontal configurations
                    # There are few possibilities: 0, 1, or 2 horizontal dominoes
                    # (0,1) covers cells 0,1 if free
                    # (1,2) covers cells 1,2 if free
                    
                    h_options = []
                    # Option: no horizontal
                    h_options.append((0, 0)) # (tiles, sum)
                    
                    # Option: (0,1)
                    if not (row_used & 1) and not (row_used & 2):
                        s = board[r][0] + board[r][1]
                        h_options.append((1, s))
                    
                    # Option: (1,2)
                    if not (row_used & 2) and not (row_used & 4):
                        s = board[r][1] + board[r][2]
                        h_options.append((1, s))
                    
                    # Option: both (0,1) and (1,2)
                    # Requires 0,1,2 all free
                    if not (row_used & 1) and not (row_used & 2) and not (row_used & 4):
                        # Note: This covers cell 1 twice if we just add, 
                        # but (0,1) and (1,2) overlap at cell 1. 
                        # In tiling, they cannot coexist. 
                        # Wait, 2x1 dominoes cannot overlap. 
                        # So (0,1) and (1,2) share cell 1. Invalid.
                        pass
                    
                    # Wait, 3 cells. We can't fit two 2x1 dominoes without overlap unless it's a 2x3 block.
                    # Horizontal dominoes are 2x1. 
                    # On 3 cells: we can place max 1 horizontal domino (2 cells) + 1 vertical (1 cell).
                    # Or 2 verticals + 1 cell empty.
                    
                    # Sum of verticals in current row
                    vert_sum = 0
                    if curr_mask & 1: vert_sum += board[r][0]
                    if curr_mask & 2: vert_sum += board[r][1]
                    if curr_mask & 4: vert_sum += board[r][2]
                    
                    for h_tiles, h_sum in h_options:
                        tot_tiles = bin(curr_mask).count('1') + h_tiles
                        new_k = prev_k + tot_tiles
                        if new_k > K: continue
                        
                        total_val = dp[prev_k][prev_mask] + vert_sum + h_sum
                        if total_val > new_dp[new_k][curr_mask]:
                            new_dp[new_k][curr_mask] = total_val
        
        dp = new_dp
    
    # Final answer: max over k <= K and all masks (no dangling verticals)
    ans = INF
    for k in range(K+1):
        for m in range(8):
            if m == 0: # Must end with no verticals extending out
                 ans = max(ans, dp[k][m])
    return ans

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_tiling(dut):
    # Clock setup
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test Case 1: Example 1
    # 5 3
    # 2 1 -1
    # 1 3 2
    # 0 2 3
    # 2 1 1
    # 3 3 0
    # We only have 8 rows in hardware, so we will test with first 8 rows or padded.
    # Since Python code handles N=5, we will verify logic with smaller N if possible,
    # but module expects 8 rows. We'll just feed 8 rows, padding the rest with 0s.
    
    board_full = [
        [2, 1, -1],
        [1, 3, 2],
        [0, 2, 3],
        [2, 1, 1],
        [3, 3, 0]
    ]
    # Pad to 8 rows
    while len(board_full) < 8:
        board_full.append([0,0,0])
        
    K = 3
    
    expected = solve_python(board_full, K)
    cocotb.log.info(f"Expected result (Python): {expected}")
    
    # Feed inputs
    # dut.row_data is expected to be a 2D array or wide vector. 
    # Assuming individual signals for simplicity based on prompt constraints.
    # Structure: row_data[row][col]
    for r in range(8):
        for c in range(3):
            val = board_full[r][c]
            # Assign to dut.row_data[r][c]
            # If row_data is flattened: 
            # dut.row_data[r*3 + c].value = clamp_to_width(val, 8)
            # Let's try accessing as 2D if synthesis supports, or handle flattened.
            # Based on prompt: "row_data[8][3][7:0]"
            # In Python cocotb, this is likely a list of lists of ModifiableObject
            
            try:
                sig = dut.row_data[r][c]
                # Handle signed conversion if needed (Verilog logic usually handles 2's complement)
                # We write the raw 8-bit value
                sig.value = clamp_to_width(val, 8)
            except Exception as e:
                # Fallback if structure is flattened or different
                # Try accessing by index if it's a flat array
                # dut.row_data[r*3 + c].value = clamp_to_width(val, 8)
                cocotb.log.warning(f"Signal access error: {e}. Check signal hierarchy.")
                # Assuming flat structure for safety if 2D fails
                try:
                    dut.row_data[r*3 + c].value = clamp_to_width(val, 8)
                except:
                    pass

    # Set K
    if has_signal(dut, 'total_K'):
        dut.total_K.value = K
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, max_cycles=2000)
    
    # Read result
    if not is_value_defined(dut.max_sum.value):
        raise TestFailure("Result signal undefined")
        
    result_val = int(dut.max_sum.value)
    # Convert signed if needed (sim usually handles int, but let's be safe)
    # If result is 16-bit signed
    result_val = to_signed(result_val, 16)
    
    cocotb.log.info(f"Got result: {result_val}")
    
    if result_val != expected:
        raise TestFailure(f"Mismatch! Expected {expected}, got {result_val}")
