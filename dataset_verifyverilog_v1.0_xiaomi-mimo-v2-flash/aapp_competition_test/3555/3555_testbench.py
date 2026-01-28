import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
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

# Fixed point helpers
Q_FORMAT_INT = 16
Q_FORMAT_FRAC = 16
Q_SHIFT = 1 << Q_FORMAT_FRAC

def float_to_fixed(f):
    return int(f * Q_SHIFT)

def fixed_to_float(v):
    return v / Q_SHIFT

# Distance calculation for testbench (reference)
def calculate_distance(x1, y1, x2, y2):
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

def is_obstacle_close(x1, y1, x2, y2, tx, ty, threshold=1.0):
    # Check if tree (tx, ty) is close to line segment (x1,y1) to (x2,y2)
    # Using cross product logic
    dx = x2 - x1
    dy = y2 - y1
    if dx == 0 and dy == 0:
        return False
    # Vector from start to tree
    vx = tx - x1
    vy = ty - y1
    # Cross product magnitude (scaled by segment length)
    cross = abs(dx * vy - dy * vx)
    # Squared length of segment
    len_sq = dx*dx + dy*dy
    # Check if perpendicular distance < threshold
    # (cross / sqrt(len_sq)) < threshold  => cross^2 < threshold^2 * len_sq
    return cross * cross < (threshold * threshold) * len_sq

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_spot_leash(dut):
    # Configuration
    CLK_NS = 10
    
    # Start Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback (rare for this problem)
        dut.rst_n.value = 1
        await Timer(100, units='ns')

    # Test Cases
    # Case 1: 2 toys, no trees
    # Toys: (10,0), (10,10)
    # Path: (0,0) -> (10,0) -> (10,10)
    # Dist: 10 + 10 = 20. Expected output ~14.14 (Direct distance?)
    # Wait, sample output is 14.14. That is dist((0,0), (10,10)) = 14.14.
    # Ah, logic: 'Spot always goes for the most shiny unchewed toy'.
    # He starts at (0,0). The most shiny toy is (10,0).
    # He goes to (10,0). Chews it.
    # Next most shiny is (10,10).
    # He goes from (10,0) to (10,10). Total dist 10 + 10 = 20.
    # BUT Sample Output 14.14. 
    # Re-read: 'How long would Spot’s leash have to be...'.
    # Maybe the leash is tied to the post, but he pulls it taut? 
    # Or is it the maximum distance from the post? 
    # 'leash length needed to reach all toys'.
    # Usually implies total path length in such problems, but 14.14 is sqrt(200).
    # Let's assume the problem implies the *radius* needed if he navigates optimally or the total path.
    # Wait, standard interpretation of 'Spot Leash' problems (e.g. Kattis 'spot') is total path length.
    # However, 14.14 is exactly sqrt(200).
    # If he goes (0,0) -> (10,0) -> (10,10), path is 20.
    # If he goes (0,0) -> (10,10) -> (10,0), path is 20.
    # If he just needs to reach (10,10) eventually, leash 14.14 reaches it.
    # 'run out of toys before he runs out of leash'.
    # Interpretation: Leash is tied to post. He pulls it taut. 
    # Max distance from post is leash length.
    # To reach (10,10), he needs 14.14.
    # To reach (10,0) then (10,10), he moves away from post. 
    # He doesn't need to return to post.
    # So leash length is the maximum distance from post he ever reaches.
    # Wait, the sample input 2 0 -> 14.14.
    # If he is at (10,0), distance is 10.
    # If he is at (10,10), distance is 14.14.
    # Max is 14.14.
    # Second sample: 2 1. Toys (10,0), (10,10). Tree (9,1).
    # Output 18.11.
    # Let's verify this logic.
    # Path (0,0) -> (10,0) -> (10,10).
    # Tree at (9,1). Is it an obstacle?
    # Segment (10,0) to (10,10) is a vertical line at x=10. Tree at x=9. Close enough?
    # If obstacle wraps, he might have to loop or go around.
    # Or maybe the tree blocks the path, forcing him to go back?
    # If blocked, he can't reach (10,10) directly.
    # Maybe he has to go to (10,0), then back out around the tree?
    # Let's assume the problem is about finding the Max Distance from Post during the journey.
    # Journey: (0,0) -> (10,0) -> (10,10).
    # Distances from (0,0): 10, 14.14. Max 14.14.
    # With tree (9,1).
    # Maybe the tree blocks the path to (10,0) or (10,10).
    # Or forces a detour.
    # Let's refine the hardware logic to simulate the "Max Distance from Origin" interpretation.
    # This matches 'leash length needed' better than total path length (which would be 20 or more).
    
    test_cases = [
        # (n, m, toys, trees, expected_max_dist)
        (2, 0, [(10,0), (10,10)], [], 14.14),
        (2, 1, [(10,0), (10,10)], [(9,1)], 18.11),
    ]

    for tc_idx, (n, m, toys, trees, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}: n={n}, m={m}")
        
        # Reset
        await reset_dut(dut)
        
        # Load Data
        total_data = n + m
        data_counted = 0
        
        # We need to feed toys first? The prompt implies input is toys then trees.
        # The spec says 'accept n toys and m trees sequentially'.
        # Input format is n toys, then m trees.
        
        # Send Toys
        for t in toys:
            dut.data_type.value = 0 # Toy
            dut.data_in.value = ((t[0] & 0xFFFF) << 16) | (t[1] & 0xFFFF)
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            data_counted += 1
            
        # Send Trees
        for tr in trees:
            dut.data_type.value = 1 # Tree
            dut.data_in.value = ((tr[0] & 0xFFFF) << 16) | (tr[1] & 0xFFFF)
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            data_counted += 1
        
        dut.data_valid.value = 0
        dut.data_count.value = data_counted
        
        # Start Processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 200
        done = False
        for _ in range(max_cycles):
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
            await RisingEdge(dut.clk)
            
        if not done:
            raise TestFailure(f"Test {tc_idx+1}: Timeout waiting for done")
            
        # Check Result
        if not has_signal(dut, 'result'):
            raise TestFailure(f"Test {tc_idx+1}: No result signal found")
            
        res_int = int(dut.result.value)
        # Convert from fixed point Q16.16 to float
        res_float = fixed_to_float(to_signed(res_int, 32))
        
        cocotb.log.info(f"Result: {res_float:.4f}, Expected: {expected:.4f}")
        
        # Allow small error for fixed point arithmetic
        if abs(res_float - expected) > 0.1:
            raise TestFailure(f"Test {tc_idx+1}: Expected {expected:.4f}, got {res_float:.4f}")
            
    cocotb.log.info("All tests passed!")
