import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_turtle_drawing_solver(dut):
    """Test turtle drawing marker drying time solver."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Simple pattern
    # Grid: 8x8, mark cells in specific pattern
    # Commands: move right 2, up 1, left 1
    # Expected: some min and max drying times
    
    # Pack 8x8 grid into 64-bit vector
    # Each row is 8 bits, row0 is LSB
    grid_val = 0
    # Mark a pattern: bottom left, then right 2, then up
    grid_val |= (1 << 0)   # (0,0)
    grid_val |= (1 << 1)   # (0,1) 
    grid_val |= (1 << 2)   # (0,2)
    grid_val |= (1 << 10)  # (1,2)
    
    # Pack commands (32 commands, 8 bits each)
    # command format: [1:0] direction, [7:2] distance
    # 00=up, 01=down, 10=left, 11=right
    commands_val = 0
    # Command 0: right 2 (direction=11, distance=2)
    commands_val |= (0b11 << 2) << 0  # bits 0-7
    # Command 1: up 1 (direction=00, distance=1)
    commands_val |= (0b00 << 2 | 0b01) << 8  # bits 8-15
    # Command 2: left 1 (direction=10, distance=1)
    commands_val |= (0b10 << 2 | 0b01) << 16  # bits 16-23
    
    dut._log.info(f"Setting grid: {grid_val:016x}")
    dut._log.info(f"Setting commands: {commands_val:032x}")
    
    dut.target_grid.value = grid_val
    dut.commands.value = commands_val
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read results
    earliest = safe_int(dut.earliest.value)
    latest = safe_int(dut.latest.value)
    
    dut._log.info(f"Results: earliest={earliest}, latest={latest}")
    
    # Convert -1 if needed
    if earliest == 255:
        earliest = -1
    if latest == 255:
        latest = -1
    
    # For this test, we expect valid values, not -1
    if earliest == -1 or latest == -1:
        raise TestFailure(f"Expected valid results, got earliest={earliest}, latest={latest}")
    
    # Verify results are reasonable
    if earliest < 0 or latest < earliest:
        raise TestFailure(f"Invalid results: earliest={earliest}, latest={latest}")
    
    dut._log.info(f"Test passed: earliest={earliest}, latest={latest}")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_impossible_pattern(dut):
    """Test case where pattern cannot be achieved."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Create impossible pattern (mark a cell that cannot be reached)
    grid_val = (1 << 63)  # Top right corner
    
    # Simple commands that don't reach top right
    commands_val = 0
    # Command 0: right 1
    commands_val |= (0b11 << 2 | 0b01) << 0
    
    dut.target_grid.value = grid_val
    dut.commands.value = commands_val
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    earliest = safe_int(dut.earliest.value)
    latest = safe_int(dut.latest.value)
    
    if earliest != 255 or latest != 255:
        raise TestFailure(f"Expected (-1,-1) for impossible pattern, got ({earliest}, {latest})")
    
    dut._log.info("Correctly identified impossible pattern")
