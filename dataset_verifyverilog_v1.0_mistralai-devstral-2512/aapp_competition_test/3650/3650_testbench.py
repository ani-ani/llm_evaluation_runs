import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sliding_blocks(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # --- Test Case 1: Possible (Simple Line) ---
    # Initial: (0,0)
    # Targets: (0,0), (1,0), (2,0)
    dut.initial_x.value = 0
    dut.initial_y.value = 0
    
    # Clear valid array
    for i in range(16):
        getattr(dut, f'block_valid_{i}').value = 0
        getattr(dut, f'target_blocks_x_{i}').value = 0
        getattr(dut, f'target_blocks_y_{i}').value = 0

    # Set block 0 (initial, implicit)
    # Set block 1 at (1, 0)
    getattr(dut, 'block_valid_1').value = 1
    getattr(dut, 'target_blocks_x_1').value = 1
    getattr(dut, 'target_blocks_y_1').value = 0
    
    # Set block 2 at (2, 0)
    getattr(dut, 'block_valid_2').value = 1
    getattr(dut, 'target_blocks_x_2').value = 2
    getattr(dut, 'target_blocks_y_2').value = 0

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.possible.value):
        raise TestFailure("Result 'possible' undefined")
    
    possible = int(dut.possible.value)
    if possible != 1:
        raise TestFailure(f"Test 1 Failed: Expected possible=1, got {possible}")
    
    cocotb.log.info("Test Case 1 Passed: Simple line configuration is possible")

    # --- Test Case 2: Impossible (Gap) ---
    # Reset
    await reset_dut(dut)
    
    # Initial: (0,0)
    # Targets: (0,0), (2,0) -> Gap at (1,0) makes (2,0) unreachable directly
    # However, the tree logic requires adjacency. Since (2,0) is not adjacent to (0,0),
    # it should fail unless (1,0) exists.
    # Let's test a valid tree that requires complex sliding
    
    # Target: (0,0), (1,0), (1,1)
    # (1,0) is adjacent to (0,0). Slide '>' on row 1 -> (1,0)
    # (1,1) is adjacent to (1,0). Slide 'v' on col 2 -> (1,1)
    
    dut.initial_x.value = 0
    dut.initial_y.value = 0
    
    for i in range(16):
        getattr(dut, f'block_valid_{i}').value = 0
    
    # Block 1: (1, 0)
    getattr(dut, 'block_valid_1').value = 1
    getattr(dut, 'target_blocks_x_1').value = 1
    getattr(dut, 'target_blocks_y_1').value = 0
    
    # Block 2: (1, 1)
    getattr(dut, 'block_valid_2').value = 1
    getattr(dut, 'target_blocks_x_2').value = 1
    getattr(dut, 'target_blocks_y_2').value = 1

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    possible = int(dut.possible.value)
    if possible != 1:
        raise TestFailure(f"Test 2 Failed: Expected possible=1, got {possible}")
        
    cocotb.log.info("Test Case 2 Passed: L-shape configuration is possible")
