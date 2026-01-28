import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Configuration
CLK_NS = 10
MAX_CYCLES = 500

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_student_matching(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test sequence
    # Input 1: D 3 1 -> Student 1
    # Input 2: D 2 2 -> Student 2
    # Input 3: D 1 3 -> Student 3
    # Input 4: P 1 -> Query Student 1 (3,1). Dominators: None (3>=3 but B<1? No, B=2 or 3, but A=2<3? No. Wait. S2: 2>=3? No. S3: 1>=3? No). Output NE.
    # Input 5: P 2 -> Query Student 2 (2,2). Dominators: None. Output NE.
    # Input 6: P 3 -> Query Student 3 (1,3). Dominators: None. Output NE.
    
    # Alternative Set 2
    # D 8 8 (S1)
    # D 2 4 (S2)
    # D 5 6 (S3)
    # P 2 (Query S2: 2,4). Dominators: S1 (8,8), S3 (5,6).
    #   S1 diff: (8-2)=6, (8-4)=4. S3 diff: (5-2)=3, (6-4)=2. 
    #   S3 is better (min B diff: 2 vs 4). Output 3.
    # D 6 2 (S4)
    # P 4 (Query S4: 6,2). Dominators: S1 (8,8).
    #   S1 diff: 2, 6. Output 1.
    
    test_vectors = [
        # (op_type, A, B, idx, expected_result_idx, description)
        # Set 1
        (0, 3, 1, 0, 0, "Add S1"),
        (0, 2, 2, 0, 0, "Add S2"),
        (0, 1, 3, 0, 0, "Add S3"),
        (1, 0, 0, 1, 0, "Query S1 -> NE"),
        (1, 0, 0, 2, 0, "Query S2 -> NE"),
        (1, 0, 0, 3, 0, "Query S3 -> NE"),
        # Reset for next set (simulated by re-running or assuming sequential log)
        # We'll just run Set 2 after a small delay/reset if needed, but usually tests are sequential
    ]
    
    # We will run Set 2 after Set 1 to keep it simple, assuming the module clears or we use a new instance (not possible in single test)
    # In hardware simulation, we just stream inputs.
    # Let's modify to run Set 2 specifically as it's the more interesting one.
    # Actually, let's do Set 2.
    
    dut._log.info("Starting Test Set 2")
    
    # Reset manually to clear state if simulation runs multiple tests on same instance
    # (Usually cocotb creates a new instance, but let's be safe and re-reset)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_vectors_set2 = [
        (0, 8, 8, 0, 0, "Add S1 (8,8)"),
        (0, 2, 4, 0, 0, "Add S2 (2,4)"),
        (0, 5, 6, 0, 0, "Add S3 (5,6)"),
        (1, 0, 0, 2, 3, "Query S2 -> S3 (5,6)"), # Index 2 is student 2. Expected helper index 3.
        (0, 6, 2, 0, 0, "Add S4 (6,2)"),
        (1, 0, 0, 4, 1, "Query S4 -> S1 (8,8)"), # Index 4 is student 4. Expected helper index 1.
    ]
    
    passed = 0
    failed = 0
    
    for op, a, b, idx, exp_res, desc in test_vectors_set2:
        cocotb.log.info(f"Executing: {desc}")
        
        # Set inputs
        if has_signal(dut, 'op_type'): dut.op_type.value = op
        if op == 0: # Add
            if has_signal(dut, 'A_in'): dut.A_in.value = clamp_to_width(a, 16)
            if has_signal(dut, 'B_in'): dut.B_in.value = clamp_to_width(b, 16)
        else: # Query
            if has_signal(dut, 'idx'): dut.idx.value = clamp_to_width(idx, 4)
            
        # Pulse start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await RisingEdge(dut.clk)
            
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"FAIL: Timeout waiting for done on {desc}")
            failed += 1
            continue
            
        # Check result
        if op == 1: # Query
            if not has_signal(dut, 'result_idx'):
                 cocotb.log.error(f"FAIL: Missing result_idx signal")
                 failed += 1
                 continue
            
            result = int(dut.result_idx.value)
            # Note: Spec says result_idx 0 for NE. 
            # My logic: 0->NE, 1->Student 1, etc.
            # Check if result matches expectation
            if result != exp_res:
                cocotb.log.error(f"FAIL: {desc}. Expected {exp_res}, got {result}")
                failed += 1
            else:
                cocotb.log.info(f"PASS: {desc}. Got {result}")
                passed += 1
        else:
            # Add op, just check no errors
            cocotb.log.info(f"PASS: {desc}")
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
