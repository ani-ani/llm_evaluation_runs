import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_CELLS = 14  # 2x7 for k=3
CLK_NS = 10
MAX_CYCLES = 10000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_alien_surgery(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: k=3, solvable from example
    # Grid from problem: row0 = [1,2,3,5,6,0,7], row1 = [8,9,10,4,11,12,13]
    # Target: row0 = [1,2,3,4,5,6,7], row1 = [13,12,11,10,9,8,0]
    grid = [
        1, 2, 3, 5, 6, 0, 7,  # row 0
        8, 9, 10, 4, 11, 12, 13  # row 1
    ]
    
    # Pack grid into individual signals arr_0 to arr_13
    for i in range(14):
        signal_name = f'arr_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(grid[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Check result
    result = int(dut.result.value)
    cocotb.log.info(f"Result: {result}")
    
    if result == 1:
        # Get packed moves
        if has_signal(dut, 'moves_out'):
            moves_packed = int(dut.moves_out.value)
            cocotb.log.info(f"Solution found, packed moves: {hex(moves_packed)}")
        else:
            cocotb.log.warning("No moves_out signal found")
    else:
        cocotb.log.warning("No solution found within move limit")
    
    # Test case 2: k=1, simple case
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # k=1 grid (2x3)
    grid2 = [1, 2, 0, 4, 3, 5]  # Unsolved
    
    for i in range(6):
        signal_name = f'arr_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(grid2[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result2 = int(dut.result.value)
    cocotb.log.info(f"Result for k=1: {result2}")
    
    # Test case 3: k=2, small grid
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # k=2 grid (2x5)
    grid3 = [1, 2, 3, 0, 5, 9, 8, 7, 6, 4]  # With empty in middle
    
    for i in range(10):
        signal_name = f'arr_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(grid3[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result3 = int(dut.result.value)
    cocotb.log.info(f"Result for k=2: {result3}")
    
    # Test case 4: Already solved
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # k=1 solved: row0=[1,2,3], row1=[4,5,0]
    grid4 = [1, 2, 3, 5, 4, 0]  # Note: row1 reversed for correct target
    
    for i in range(6):
        signal_name = f'arr_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(grid4[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result4 = int(dut.result.value)
    cocotb.log.info(f"Result for solved grid: {result4}")
    
    # Test case 5: Random permutation
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # Generate random permutation of 1..7 with one empty
    nums = list(range(1, 8))
    random.shuffle(nums)
    grid5 = nums + [8, 9, 10, 11, 12, 13, 0]  # Second row as is
    
    for i in range(14):
        signal_name = f'arr_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(grid5[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result5 = int(dut.result.value)
    cocotb.log.info(f"Result for random grid: {result5}")
    
    # Final check: ensure all signals exist
    required_signals = ['clk', 'rst_n', 'start', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Required signal '{sig}' not found")
    
    cocotb.log.info("All tests completed successfully")
