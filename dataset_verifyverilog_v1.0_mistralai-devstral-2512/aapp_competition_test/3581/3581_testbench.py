import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except: return False

def clamp(v, bits): return min((1<<bits)-1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except:
        return False

# Fixed point conversion (Q16.16)
def float_to_q1616(f): return int(f * 65536)

def int_to_q1616(i): return i * 65536

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_arcade(dut):
    # Setup
    if not has_signal(dut, 'clk'):
        # Combinational only? Assume timeout handles it
        await Timer(1, units='ns')
        return
        
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    for _ in range(5): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Small 2-row example
    N = 2
    v = [100, 50, 50]
    # P0, P1, P2, P3, P4
    probs = [
        [0.0, 0.0, 0.45, 0.45, 0.1],
        [0.0, 0.90, 0.0, 0.0, 0.10],
        [0.90, 0.0, 0.0, 0.0, 0.10]
    ]
    
    # Expected output from problem: 76.31578947368
    # Expected value calculation (manual):
    # E2 = 50 / 0.1 = 500 (since only P4=0.1 stops it, others bounce back to hole 2? No, neighbors are 0 and 1.
    # Neighbors for hole 2 (row 1, col 1):
    # TL: Hole 1 (row 0, col 0)
    # TR: None
    # BL: None
    # BR: None
    # Wait, problem statement: Holes are triangular.
    # Row 0: Hole 1
    # Row 1: Holes 2, 3
    # Indices: 0, 1, 2
    # 
    # Hole 0 (v=100):
    # TL: -1, TR: -1
    # BL: Hole 1 (row 1, col 0)
    # BR: Hole 2 (row 1, col 1)
    # 
    # Hole 1 (v=50):
    # TL: Hole 0 (row 0, col 0)
    # TR: -1
    # BL: -1
    # BR: -1
    # 
    # Hole 2 (v=50):
    # TL: Hole 0 (row 0, col 0) ? No. 
    # Hole 2 is row 1, col 1.
    # TL: Row 0, col 0 (Hole 0)
    # TR: Row 0, col 1? No, row 0 has only 1 hole.
    # BL: Row 2? No, N=2.
    # BR: None.
    # 
    # The sample input says:
    # Hole 2 (index 2) probs: 0.90 0.0 0.0 0.0 0.10
    # TL (p0=0.90): Hole 0
    # TR (p1=0.0): None
    # BL (p2=0.0): None
    # BR (p3=0.0): None
    # 
    # Equation:
    # E0 = 100 + 0.45*E1 + 0.45*E2 + 0.1*100? No, p4 is enter hole.
    # p4 is probability ball enters hole (stops).
    # If p4=0.1, then 0.1 chance of getting v[i].
    # Wait, input format: "p0 p1 p2 p3 p4".
    # If p4 is probability it enters hole (ends game). 
    # Then E[i] = p0*E[TL] + p1*E[TR] + p2*E[BL] + p3*E[BR] + p4*v[i].
    # Standard expected value: E = sum(prob * value).
    # Yes, if it enters hole, value is v[i].
    # 
    # Hole 0: E0 = 0.45*E1 + 0.45*E2 + 0.1*100
    # Hole 1: E1 = 0.0*E0 + 0.90*... (Wait sample input row 2 hole 2 is index 1? No input lists hole 1 first.
    # Sample Input 2:
    # 2
    # 100 50 50  (v0=100, v1=50, v2=50)
    # Probs for hole 1 (index 0): 0.0 0.0 0.45 0.45 0.1
    # Probs for hole 2 (index 1): 0.0 0.90 0.0 0.0 0.10
    # Probs for hole 3 (index 2): 0.90 0.0 0.0 0.0 0.10
    # 
    # Hole 1 (Index 0):
    # p0 (TL): 0.0 -> None
    # p1 (TR): 0.0 -> None
    # p2 (BL): 0.45 -> Hole 2 (Index 1)
    # p3 (BR): 0.45 -> Hole 3 (Index 2)
    # p4: 0.1 -> V0 (100)
    # E0 = 0.45*E1 + 0.45*E2 + 0.1*100
    # 
    # Hole 2 (Index 1):
    # p0 (TL): 0.0 -> Hole 1 (Index 0)? No, p0 is 0.0 here.
    # p1 (TR): 0.90 -> Hole 3 (Index 2)? No, p1 is 0.90.
    # Wait, Hole 2 (row 1, col 0) neighbors: TL (hole 1), TR (none), BL (none), BR (none).
    # Sample says: 0.0 0.90 0.0 0.0 0.10
    # This implies p1 (TR) is 0.90, but TR doesn't exist. 
    # Ah, problem says: "If a hole does not have certain neighbors... probability is zero."
    # The input might contain non-zero probs for invalid neighbors? 
    # "It is guaranteed that 0.0 <= pi <= 1.0 ... probabilities to jump to non-existent neighbors is always zero."
    # The input lists probabilities. We must ignore probabilities pointing to non-existent neighbors? 
    # Or does the problem provide the probabilities for the valid ones and 0 for others?
    # "For instance, for hole number 1, the probabilities to jump to the top-left and top-right neighbors are both given as 0.0."
    # This suggests the input values ARE correct for the geometry.
    # So for Hole 2 (Index 1): TL (p0) is 0.0. TR (p1) is 0.90. 
    # Hole 2 is row 1, col 0. TR neighbor is Row 0, col 1? No. 
    # Row 1 (2nd row) has holes 2 (col 0) and 3 (col 1).
    # Hole 2 (col 0): TL -> None, TR -> None? No, TR is Hole 3 (row 1, col 1)??? 
    # The description: "top-left, top-right, bottom-left, bottom-right".
    # In a triangular grid (triangle pointing up):
    # Row 0:   0
    # Row 1:  1 2
    # Row 2: 3 4 5
    # Hole 0 (row 0): Neighbors 1 (BL), 2 (BR).
    # Hole 1 (row 1, col 0): Neighbors 0 (TR? no, TL? depends on drawing). 
    # Standard geometry: 
    # - Top-Left: (r-1, c-1)
    # - Top-Right: (r-1, c)
    # - Bottom-Left: (r+1, c)
    # - Bottom-Right: (r+1, c+1)
    # 
    # Hole 1 (Index 1, r=1, c=0):
    # TL: (0, -1) -> None
    # TR: (0, 0) -> Hole 0 (Index 0)
    # BL: (2, 0) -> Hole 3 (Index 3)
    # BR: (2, 1) -> Hole 4 (Index 4)
    # 
    # But sample input 2 only has 3 holes (N=2 -> 3 holes).
    # N=2 means rows 0 and 1.
    # Hole 1 (Index 1): 
    # TL: None
    # TR: Hole 0
    # BL: None (row 2 doesn't exist)
    # BR: None
    # 
    # Sample Input 2 Probabilities for Hole 2 (Index 1):
    # 0.0 0.90 0.0 0.0 0.10
    # p0 (TL)=0.0, p1 (TR)=0.90, p2 (BL)=0.0, p3 (BR)=0.0, p4=0.1
    # This maps p1 (TR) to Hole 0. This is geometrically correct for (r=1, c=0) -> (r=0, c=0).
    # 
    # Hole 3 (Index 2, r=1, c=1):
    # TL: (0, 0) -> Hole 0
    # TR: (0, 1) -> None
    # BL: (2, 1) -> None
    # BR: (2, 2) -> None
    # Sample Input 2 Probabilities for Hole 3 (Index 2):
    # 0.90 0.0 0.0 0.0 0.10
    # p0 (TL)=0.90 -> Hole 0. Correct.
    # 
    # So the system of equations:
    # E0 = 0.45*E1 + 0.45*E2 + 0.1*100
    # E1 = 0.90*E0 + 0.1*50
    # E2 = 0.90*E0 + 0.1*50
    # 
    # Substitute E1=E2:
    # E0 = 0.9*E1 + 10
    # E1 = 0.9*E0 + 5
    # E0 = 0.9*(0.9*E0 + 5) + 10 = 0.81*E0 + 4.5 + 10
    # 0.19*E0 = 14.5
    # E0 = 14.5 / 0.19 = 76.3157...
    # Output is 76.31578947368. Correct.
    
    H = 3
    
    # Load Data
    for i in range(H):
        dut.data_idx.value = i
        dut.data_v.value = int_to_q1616(v[i]) # Scale v to Q16.16 (though v is integer, we operate in fixed point)
        
        # Probabilities scaled to Q16.16 (0.0 - 1.0)
        p = probs[i]
        dut.data_p0.value = float_to_q1616(p[0])
        dut.data_p1.value = float_to_q1616(p[1])
        dut.data_p2.value = float_to_q1616(p[2])
        dut.data_p3.value = float_to_q1616(p[3])
        dut.data_p4.value = float_to_q1616(p[4])
        
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        dut.data_valid.value = 0
        await RisingEdge(dut.clk) # Small gap
        
    # Start Solver
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 2000
    done = False
    for _ in range(max_cycles):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure(f"Did not finish within {max_cycles} cycles")
        
    # Check Result
    # Expected: 76.315789... Scaled to Q16.16 (65536) -> 76.3157 * 65536 = 4999999 (approx)
    # Allow some error tolerance (1/10000 relative)
    
    result_val = int(dut.result.value)
    result_float = result_val / 65536.0
    
    expected = 76.31578947368
    error = abs(result_float - expected)
    
    cocotb.log.info(f"Result: {result_float} (Raw: {result_val})")
    cocotb.log.info(f"Expected: {expected}")
    cocotb.log.info(f"Error: {error}")
    
    # Tolerance 1e-4 as per problem statement
    if error > 1e-4:
        raise TestFailure(f"Error {error} > 1e-4")
