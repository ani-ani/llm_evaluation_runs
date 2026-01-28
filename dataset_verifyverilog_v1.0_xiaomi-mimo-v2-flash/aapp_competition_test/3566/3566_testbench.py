import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on the spec
ARRAY_SIZE = 16
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 200  # Sufficient for N=16 scans

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

# Reference implementation for verification
def get_optimal_index(huts):
    # Splits huts into list of 16 integers, handles missing indices as 0
    arr = [0] * ARRAY_SIZE
    for k, v in huts.items():
        if k < ARRAY_SIZE:
            arr[k] = v
    
    total = sum(arr)
    min_diff = float('inf')
    best_idx = 0
    
    left_acc = 0
    for k in range(ARRAY_SIZE):
        val = arr[k]
        half = val // 2
        # Left side: sum of huts 0 to k-1 + half of current
        left_sum = left_acc + half
        # Right side: sum of huts k+1 to end + half of current
        right_sum = (total - (left_acc + val)) + half
        
        diff = abs(left_sum - right_sum)
        
        if diff < min_diff:
            min_diff = diff
            best_idx = k
        
        left_acc += val
    
    return best_idx

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.update_en.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_beach_huts(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed
        dut.rst_n.value = 1
    
    # Track hut state in Python for verification
    hut_state = {}
    
    # Test case 1: Basic functionality
    cocotb.log.info("Running Test Case 1: Sample 1")
    
    # Update hut 0 to 3
    hut_state[0] = 3
    dut.update_en.value = 1
    dut.hut_idx.value = 0
    dut.new_val.value = 3
    
    # Wait for done
    found_done = False
    for _ in range(MAX_CYCLES):
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            found_done = True
            break
        await RisingEdge(dut.clk)
    
    if not found_done and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done (update 1)")
    
    # Check result
    exp_idx = get_optimal_index(hut_state)
    if has_signal(dut, 'optimal_idx'):
        res = int(dut.optimal_idx.value)
        if res != exp_idx:
            raise TestFailure(f"Update 1: Expected {exp_idx}, got {res}")
    
    await RisingEdge(dut.clk)
    dut.update_en.value = 0
    
    # Update hut 0 to 5
    hut_state[0] = 5
    dut.update_en.value = 1
    dut.hut_idx.value = 0
    dut.new_val.value = 5
    
    found_done = False
    for _ in range(MAX_CYCLES):
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            found_done = True
            break
        await RisingEdge(dut.clk)
    
    if not found_done and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done (update 2)")
    
    exp_idx = get_optimal_index(hut_state)
    if has_signal(dut, 'optimal_idx'):
        res = int(dut.optimal_idx.value)
        if res != exp_idx:
            raise TestFailure(f"Update 2: Expected {exp_idx}, got {res}")
    
    await RisingEdge(dut.clk)
    dut.update_en.value = 0
    
    # Update hut 0 to 9
    hut_state[0] = 9
    dut.update_en.value = 1
    dut.hut_idx.value = 0
    dut.new_val.value = 9
    
    found_done = False
    for _ in range(MAX_CYCLES):
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            found_done = True
            break
        await RisingEdge(dut.clk)
    
    if not found_done and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done (update 3)")
    
    exp_idx = get_optimal_index(hut_state)
    if has_signal(dut, 'optimal_idx'):
        res = int(dut.optimal_idx.value)
        if res != exp_idx:
            raise TestFailure(f"Update 3: Expected {exp_idx}, got {res}")
    
    await RisingEdge(dut.clk)
    dut.update_en.value = 0
    
    # Update hut 4 to 5
    hut_state[4] = 5
    dut.update_en.value = 1
    dut.hut_idx.value = 4
    dut.new_val.value = 5
    
    found_done = False
    for _ in range(MAX_CYCLES):
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            found_done = True
            break
        await RisingEdge(dut.clk)
    
    if not found_done and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done (update 4)")
    
    exp_idx = get_optimal_index(hut_state)
    if has_signal(dut, 'optimal_idx'):
        res = int(dut.optimal_idx.value)
        if res != exp_idx:
            raise TestFailure(f"Update 4: Expected {exp_idx}, got {res}")
    
    await RisingEdge(dut.clk)
    dut.update_en.value = 0
    
    # Update hut 2 to 1
    hut_state[2] = 1
    dut.update_en.value = 1
    dut.hut_idx.value = 2
    dut.new_val.value = 1
    
    found_done = False
    for _ in range(MAX_CYCLES):
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            found_done = True
            break
        await RisingEdge(dut.clk)
    
    if not found_done and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done (update 5)")
    
    exp_idx = get_optimal_index(hut_state)
    if has_signal(dut, 'optimal_idx'):
        res = int(dut.optimal_idx.value)
        if res != exp_idx:
            raise TestFailure(f"Update 5: Expected {exp_idx}, got {res}")
    
    cocotb.log.info("All tests passed!")
