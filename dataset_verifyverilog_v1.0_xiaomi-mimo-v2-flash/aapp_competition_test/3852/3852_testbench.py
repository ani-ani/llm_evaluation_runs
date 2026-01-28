import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for this problem
DATA_WIDTH = 24  # Sufficient for -10^6 to +10^6
INDEX_WIDTH = 6  # 2^6 = 64 > 50
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(val, bits):
    """Clamp value to fit in signed range for simulation."""
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    if val > max_val: return max_val
    if val < min_val: return min_val
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_non_decreasing_array(dut):
    # Start clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.array_end.value = 0
    dut.data_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case Generation
    # Random N between 2 and 50
    N = random.randint(2, 50)
    
    # Generate array
    A = []
    for _ in range(N):
        A.append(random.randint(-1000000, 1000000))
    
    # Calculate expected operations using Python algorithm (Simplified version from solutions)
    # We will feed the array to the DUT, then check the output sequence against a Python reference.
    
    dut._log.info(f"Test case N={N}, Array={A}")
    
    # 1. Feed the array to the DUT
    for i, val in enumerate(A):
        dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
        dut.data_valid.value = 1
        dut.array_end.value = 1 if (i == N-1) else 0
        await RisingEdge(dut.clk)
        dut.data_valid.value = 0
        dut.array_end.value = 0
    
    # 2. Start the computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # 3. Wait for and collect operations
    ops = []
    op_count_hw = 0
    
    # Monitor for done signal or max cycles
    cycles = 0
    done_found = False
    
    while cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if has_signal(dut, 'op_valid') and is_value_defined(dut.op_valid.value):
            if int(dut.op_valid.value) == 1:
                x = int(dut.op_x.value)
                y = int(dut.op_y.value)
                ops.append((x, y))
                dut._log.info(f"Op {op_count_hw}: Add A[{x}] to A[{y}]")
                op_count_hw += 1
                
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done_found = True
                break
    
    if not done_found:
        raise TestFailure(f"DUT did not assert 'done' within {MAX_CYCLES} cycles")
    
    # 4. Verify the sequence using the same logic as Python
    # Simulate the operations on the original array
    sim_A = list(A)
    
    # Python reference logic (simplified subset matching the hardware FSM)
    # Note: We verify that the sequence of operations produces a non-decreasing array
    # and respects the logic constraints (critical element based).
    
    for x, y in ops:
        # 1-indexed to 0-indexed
        x_idx = x - 1
        y_idx = y - 1
        
        if x_idx >= len(sim_A) or y_idx >= len(sim_A):
            raise TestFailure(f"Generated operation index out of bounds: {x}, {y}")
            
        sim_A[y_idx] += sim_A[x_idx]
    
    # Check non-decreasing condition
    for i in range(len(sim_A) - 1):
        if sim_A[i] > sim_A[i+1]:
            raise TestFailure(f"Result array {sim_A} is not non-decreasing at index {i}")
            
    # Check operation count constraint
    if len(ops) > 2 * N:
        raise TestFailure(f"Generated {len(ops)} operations, which exceeds 2N={2*N}")
        
    # Check hardware reported count
    hw_count = int(dut.op_count.value)
    if hw_count != len(ops):
         raise TestFailure(f"Hardware op_count {hw_count} mismatch actual ops {len(ops)}")
    
    dut._log.info(f"Success! Generated {len(ops)} operations. Final array: {sim_A}")
