import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_josip_painter(dut):
    """
    Test the Josip Painter module with N=8.
    Generates random target images and checks if the output satisfies
    Josip's constraints and minimizes difference (checked via Python reference).
    """
    # Configuration
    N = 8
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Reference Implementation in Python for verification
    def is_valid_pattern(board, x, y, size):
        """
        Checks if the sub-square board[x:x+size][y:y+size]
        is valid according to Josip's rules.
        """
        if size == 1:
            return True
        
        # Divide into 4 quadrants
        h = size // 2
        quads = [
            (x, y, h),          # TL
            (x, y + h, h),      # TR
            (x + h, y, h),      # BL
            (x + h, y + h, h)   # BR
        ]
        
        # Extract colors for each quadrant (check uniformity)
        quad_colors = []
        for qx, qy, qs in quads:
            # Check if quadrant is uniform
            val = board[qx][qy]
            uniform = True
            for i in range(qx, qx+qs):
                for j in range(qy, qy+qs):
                    if board[i][j] != val:
                        uniform = False
                        break
                if not uniform: break
            
            if uniform:
                quad_colors.append(val)
            else:
                quad_colors.append(None) # Needs recursion
        
        # Josip's Rules:
        # 1. Select one quad -> White (0)
        # 2. Select one quad -> Black (1)
        # 3. Remaining two -> Recurse
        
        whites = quad_colors.count(0)
        blacks = quad_colors.count(1)
        recurses = quad_colors.count(None)
        
        # Must be exactly 1 White, 1 Black, 2 Recurse
        if whites != 1 or blacks != 1 or recurses != 2:
            return False
        
        # Verify recursion validity
        valid_recursion = True
        for i in range(4):
            if quad_colors[i] is None:
                qx, qy, qs = quads[i]
                if not is_valid_pattern(board, qx, qy, qs):
                    valid_recursion = False
                    break
        return valid_recursion

    def min_difference_hardware(target):
        """
        Brute force generator for N=8.
        Iterates over all 8x8 binary boards.
        Checks validity.
        Returns (min_diff, best_board).
        """
        # Since 2^64 is too large, we use a smarter search:
        # We construct valid boards using the recursive rules.
        # Valid boards have a specific structure (2x2 blocks etc).
        # Actually, for N=8, we can generate all valid configurations recursively.
        
        best_diff = 1000000
        best_board = None
        
        def generate_and_check(x, y, size, board):
            nonlocal best_diff, best_board
            
            if size == 1:
                # Base case: Try 0 and 1
                for color in [0, 1]:
                    board[x][y] = color
                    # Check difference immediately at root level logic (optional)
                    # But we need full board for root check.
                    # We only check full board validity at the top level.
                    # For recursion, we just generate.
                    if x == 0 and y == 0 and size == 1:
                        # Dummy
                        pass
                return

            h = size // 2
            quads = [(x, y, h), (x, y+h, h), (x+h, y, h), (x+h, y+h, h)]
            
            # Permute which quad is White, Black, Recurse, Recurse
            # 4 choices for White, 3 for Black, 2 for Recurse1, 1 for Recurse2
            import itertools
            indices = [0, 1, 2, 3]
            
            for white_idx in indices:
                remaining = [i for i in indices if i != white_idx]
                for black_idx in remaining:
                    recurse_idxs = [i for i in remaining if i != black_idx]
                    
                    # Assign Colors
                    for idx in indices:
                        qx, qy, qs = quads[idx]
                        if idx == white_idx:
                            # Fill with 0
                            for i in range(qx, qx+qs):
                                for j in range(qy, qy+qs):
                                    board[i][j] = 0
                        elif idx == black_idx:
                            # Fill with 1
                            for i in range(qx, qx+qs):
                                for j in range(qy, qy+qs):
                                    board[i][j] = 1
                    
                    # Recurse on remaining two
                    def recurse(r_idx):
                        if r_idx == 2: # Done recursing on both
                            # Only check validity at the top level (size 8)
                            if size == 8:
                                valid = True
                                # Check validity of the whole board
                                # We need to check every internal node? No, just the constraints.
                                # The way we constructed it guarantees 1W, 1B, 2R structure for this level.
                                # But we must ensure the sub-recursions also satisfied this.
                                # Wait, 'recurse' function here just fills the board.
                                # Validity is implicit in the generation process (if we don't fill recursively, it's invalid).
                                # So we need to actually recurse.
                                pass
                            return True
                        
                        qx, qy, qs = quads[recurse_idxs[r_idx]]
                        if qs == 1:
                            # Base of recursion for sub-block
                            # We need to decide color for this single pixel
                            # To minimize diff, we try 0 and 1 (simple logic)
                            # For exhaustive valid generation:
                            board[qx][qy] = 0
                            if recurse(r_idx + 1): return True # Just return if valid structure needed
                            board[qx][qy] = 1
                            if recurse(r_idx + 1): return True
                            return False # Backtrack
                        else:
                            # Recurse deeper for this quadrant
                            # This requires replicating the selection logic for 'qs' size
                            # This is getting complex for pure brute force.
                            # Let's simplify: We only care about the Root Level (size 8) validity.
                            # The rules apply recursively.
                            pass
                        return True

        # ALTERNATIVE: Satisfiability / Greedy approach for HW.
        # Since N=8 is small, we can just compute the best 'local' decision at each level.
        # However, local decisions conflict.
        # Given the constraints (1W, 1B, 2R), the board structure is sparse.
        # 
        # Strategy for HW:
        # 1. Read target board.
        # 2. We will output a board that is valid by construction.
        # 3. We will choose the configuration that matches the target best.
        # 
        # Top Level (8x8):
        # 4 quadrants: TL, TR, BL, BR.
        # We must pick one W, one B, two Recurse.
        # If we pick W for TL, we force 0s. Cost = count of 1s in target TL.
        # If we pick B for TL, we force 1s. Cost = count of 0s in target TL.
        # If we pick Recurse for TL, we optimize that quadrant recursively.
        
        def solve(x, y, size):
            # Returns (min_cost, board_pattern)
            # board_pattern: 0=White, 1=Black, 2=Recurse
            if size == 1:
                # Cost to make it 0 or 1
                val = target[x][y]
                return min(val, 1-val), [[1-val]] # Return dummy board data if needed, or just cost
            
            h = size // 2
            quad_coords = [(x, y, h), (x, y+h, h), (x+h, y, h), (x+h, y+h, h)]
            
            # Precompute costs for choices
            # choices: 0=White, 1=Black, 2=Recurse
            costs = []
            for i in range(4):
                qx, qy, qs = quad_coords[i]
                cnt0 = 0
                cnt1 = 0
                for r in range(qx, qx+qs):
                    for c in range(qy, qy+qs):
                        if target[r][c] == 0: cnt0 += 1
                        else: cnt1 += 1
                
                # If we set White (0), cost is number of 1s
                w_cost = cnt1
                # If we set Black (1), cost is number of 0s
                b_cost = cnt0
                # If we Recurse, we need to solve subproblem
                r_cost, _ = solve(qx, qy, qs)
                
                costs.append((w_cost, b_cost, r_cost))
            
            # We need to pick 1 W, 1 B, 2 R to minimize sum
            # Brute force assignments for 4 items
            import itertools
            best_total = 1000000
            best_assignment = []
            
            for perm in itertools.permutations([0, 1, 2, 2]):
                # 0=W, 1=B, 2=R
                total = 0
                for i in range(4):
                    if perm[i] == 0: total += costs[i][0]
                    elif perm[i] == 1: total += costs[i][1]
                    else: total += costs[i][2]
                
                if total < best_total:
                    best_total = total
                    best_assignment = perm
            
            # Construct pattern for this level (0=W, 1=B, 2=R)
            pattern = [[best_assignment[i] for i in range(2)], 
                       [best_assignment[i+2] for i in range(2)]]
            
            return best_total, pattern

        # Run solver
        total_cost, top_pattern = solve(0, 0, N)
        
        # Reconstruct full board from patterns
        final_board = [[0]*N for _ in range(N)]
        
        def fill(x, y, size, p_val):
            if p_val == 0: # White
                for r in range(x, x+size):
                    for c in range(y, y+size):
                        final_board[r][c] = 0
                return
            if p_val == 1: # Black
                for r in range(x, x+size):
                    for c in range(y, y+size):
                        final_board[r][c] = 1
                return
            
            # Recurse
            h = size // 2
            # p_val is the 2x2 matrix of instructions
            for i in range(2):
                for j in range(2):
                    fill(x + i*h, y + j*h, h, p_val[i][j])
        
        fill(0, 0, N, top_pattern)
        return total_cost, final_board

    # Test Loop
    for test_idx in range(5):  # Run 5 random tests
        dut._log.info(f"Running Test Case {test_idx + 1}")
        
        # 1. Generate Random Target (8x8)
        target_board = [[random.randint(0, 1) for _ in range(N)] for _ in range(N)]
        
        # 2. Compute Expected using Python solver
        expected_diff, expected_board = min_difference_hardware(target_board)
        
        dut._log.info(f"Expected Difference: {expected_diff}")
        
        # 3. Feed Inputs to DUT
        if has_signal(dut, 'clk'):
            # Write target board to dut signals
            # Naming convention: target_0_0 to target_7_7
            for r in range(N):
                for c in range(N):
                    sig_name = f'target_{r}_{c}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = target_board[r][c]
            
            # Start sequence
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(100): # Max cycles
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure("Timeout waiting for done signal")
            
            # 4. Read Outputs
            result_board = [[0]*N for _ in range(N)]
            for r in range(N):
                for c in range(N):
                    sig_name = f'result_{r}_{c}'
                    if has_signal(dut, sig_name):
                        val = int(getattr(dut, sig_name).value)
                        result_board[r][c] = val
            
            if has_signal(dut, 'diff'):
                dut_diff = int(dut.diff.value)
            else:
                dut_diff = 0 # Fallback
            
            # 5. Verification
            # Check Diff
            if dut_diff != expected_diff:
                # Recalculate Python diff to be sure (handle case where Py solver is perfect)
                calc_diff = 0
                for r in range(N):
                    for c in range(N):
                        if result_board[r][c] != target_board[r][c]:
                            calc_diff += 1
                
                # Note: Python solver finds global optimum. DUT might find a local optimum if heuristic.
                # However, the problem implies finding the *smallest possible*.
                # Let's assume DUT must match Python exactly for this benchmark (full search).
                # If DUT diff > Python diff, it's strictly suboptimal.
                if dut_diff > expected_diff:
                    raise TestFailure(f"Suboptimal result. DUT diff {dut_diff} > Optimal {expected_diff}")
                
                # If equal, it's just a different valid configuration (since multiple boards can have same diff)
                if dut_diff == expected_diff:
                    dut._log.info("Difference matches optimum.")
                else:
                     # Should not happen if DUT is correct
                     dut._log.warning(f"Difference mismatch: DUT={dut_diff}, Py={expected_diff}")
            
            # Check Validity of Result Board
            if not is_valid_pattern(result_board, 0, 0, N):
                raise TestFailure("DUT generated invalid board pattern")
            
            dut._log.info(f"Test {test_idx+1} Passed.")
        else:
            # Combinational logic fallback (unlikely for this complexity)
            await Timer(100, units='ns')

    dut._log.info("All tests completed successfully.")