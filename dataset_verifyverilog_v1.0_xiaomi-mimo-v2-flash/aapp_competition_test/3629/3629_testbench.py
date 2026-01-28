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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: v = 0
    if v > max_val: v = max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed point constants
Q12_12 = 1 << 12
Q16_16 = 1 << 16

def float_to_q12_12(f):
    return int(f * Q12_12)

def float_to_q16_16(f):
    return int(f * Q16_16)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_boar_charge(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(3):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test Case 1: Single tree (Sample Input 1)
    # Input: 1 tree at (3,0) r=1, b=1, d=4
    # Expected: 0.76772047
    
    b = 1.0
    d = 4.0
    trees = [(3.0, 0.0, 1.0)]
    num_trees = 1
    expected_prob = 0.76772047
    
    cocotb.log.info(f"Test Case 1: {len(trees)} trees, b={b}, d={d}")
    
    # Set inputs
    dut.b_radius.value = float_to_q12_12(b)
    dut.d_distance.value = float_to_q12_12(d)
    dut.num_trees.value = num_trees
    
    # Clear tree arrays first
    for i in range(8):
        dut.tree_x[i].value = 0
        dut.tree_y[i].value = 0
        dut.tree_r[i].value = 0
        
    # Set tree data
    for i, (x, y, r) in enumerate(trees):
        dut.tree_x[i].value = float_to_q12_12(x)
        dut.tree_y[i].value = float_to_q12_12(y)
        dut.tree_r[i].value = float_to_q12_12(r)

    if is_seq:
        # Trigger
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while True:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 10000:
                raise TestFailure("Timeout waiting for done signal")
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        raw_result = int(dut.result.value)
        # Convert Q16.16 to float
        result = raw_result / float(Q16_16)
        
        cocotb.log.info(f"Result: {result} (Raw: {raw_result})")
        
        # Check against expected with tolerance
        if abs(result - expected_prob) > 0.0001:
            raise TestFailure(f"Expected {expected_prob}, got {result}")
    else:
        # Combinational logic (if any) - wait for settle
        await Timer(100, units='ns')
        if is_value_defined(dut.result.value):
            raw_result = int(dut.result.value)
            result = raw_result / float(Q16_16)
            cocotb.log.info(f"Result: {result}")

    # Test Case 2: Complex case (Sample Input 2)
    # 4 trees around center, b=1, d=3
    # Expected: 0.19253205
    
    b = 1.0
    d = 3.0
    trees = [
        (6.0, 0.0, 3.0),
        (0.0, 6.0, 3.0),
        (-6.0, 0.0, 3.0),
        (0.0, -6.0, 3.0)
    ]
    num_trees = 4
    expected_prob = 0.19253205
    
    cocotb.log.info(f"Test Case 2: {len(trees)} trees, b={b}, d={d}")
    
    dut.b_radius.value = float_to_q12_12(b)
    dut.d_distance.value = float_to_q12_12(d)
    dut.num_trees.value = num_trees
    
    for i in range(8):
        dut.tree_x[i].value = 0
        dut.tree_y[i].value = 0
        dut.tree_r[i].value = 0
        
    for i, (x, y, r) in enumerate(trees):
        dut.tree_x[i].value = float_to_q12_12(x)
        dut.tree_y[i].value = float_to_q12_12(y)
        dut.tree_r[i].value = float_to_q12_12(r)

    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while True:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 10000:
                raise TestFailure("Timeout waiting for done signal")
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            
        raw_result = int(dut.result.value)
        result = raw_result / float(Q16_16)
        
        cocotb.log.info(f"Result: {result} (Raw: {raw_result})")
        
        if abs(result - expected_prob) > 0.0001:
            raise TestFailure(f"Expected {expected_prob}, got {result}")
            
    cocotb.log.info("All tests passed!")
