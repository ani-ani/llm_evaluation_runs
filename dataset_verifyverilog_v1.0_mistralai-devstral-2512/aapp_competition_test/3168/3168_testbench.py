import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_bst_insert(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'val'):
        dut.val.value = 0
    
    # Minimum 2 cycles reset
    if is_seq:
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    if is_seq:
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')
    
    # Test sequences (scaled for N≤16, values 1-256)
    # Expected outputs from scaled Python simulation
    test_cases = [
        # Input: [values], Expected: [cumulative depths]
        ([1, 2, 3, 4], [0, 1, 3, 6]),
        ([3, 2, 4, 1, 5], [0, 1, 2, 4, 6]),
        ([3, 5, 1, 6, 8, 7, 2, 4], [0, 1, 2, 4, 7, 11, 13, 15])
    ]
    
    for seq_idx, (values, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {seq_idx + 1}: Inserting {values}")
        
        # Reset result tracking
        prev_result = 0
        
        for i, val in enumerate(values):
            # Drive inputs
            if has_signal(dut, 'val'):
                dut.val.value = clamp_to_width(val, 8)
            
            # Pulse start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if is_seq:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                dut.start.value = 0
            else:
                # For combinational, just wait
                await Timer(10, units='ns')
            
            # Wait for done (bounded)
            done_seen = False
            max_cycles = 20
            for _ in range(max_cycles):
                if is_seq:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure(f"Timeout waiting for done on insertion {i}")
            
            # Check result
            if has_signal(dut, 'result'):
                if not is_value_defined(dut.result.value):
                    raise TestFailure(f"Result undefined on insertion {i}")
                
                result = int(dut.result.value)
                exp = expected[i]
                
                if result != exp:
                    raise TestFailure(
                        f"Seq {seq_idx}, Insert {i} (val={val}): "
                        f"Expected cumulative sum {exp}, Got {result}"
                    )
                
                dut._log.info(f"  Insert {i} val={val}: result={result} (expected {exp}) ✓")
                prev_result = result
            
            # Small delay between insertions
            if is_seq:
                await Timer(5, units='ns')
            else:
                await Timer(5, units='ns')
    
    dut._log.info("All test cases passed!")

# Additional helper for manual verification if needed
async def read_tree_state(dut):
    """Helper to read internal tree state for debugging"""
    state = {}
    for field in ['root_idx', 'free_idx', 'node_val', 'node_left', 'node_right']:
        if has_signal(dut, field):
            state[field] = int(dut.__getattr__(field).value)
    return state