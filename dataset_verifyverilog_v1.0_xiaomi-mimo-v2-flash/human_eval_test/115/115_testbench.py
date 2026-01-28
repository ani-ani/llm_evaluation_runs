import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 8
GRID_ROWS = 8
GRID_COLS = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(grid, capacity):
    total = 0
    for row in grid:
        water = sum(row)
        drops = math.ceil(water / capacity) if water > 0 else 0
        total += drops
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_fill(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([[0,0,1,0], [0,1,0,0], [1,1,1,1]], 1, 6),
        ([[0,0,1,1], [0,0,0,0], [1,1,1,1], [0,1,1,1]], 2, 5),
        ([[0,0,0], [0,0,0]], 5, 0),
        ([[1,1,1,1], [1,1,1,1]], 2, 4),
        ([[1,1,1,1], [1,1,1,1]], 9, 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, capacity, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: grid={grid}, capacity={capacity}, expected={expected}")
        
        # Expand grid to 8x8 (pad with zeros)
        padded_grid = []
        for row in grid:
            padded_row = row + [0] * (GRID_COLS - len(row))
            padded_grid.append(padded_row)
        while len(padded_grid) < GRID_ROWS:
            padded_grid.append([0] * GRID_COLS)
        
        # Write grid to DUT
        for r in range(GRID_ROWS):
            for c in range(GRID_COLS):
                signal_name = f'grid_{r}_{c}' if has_signal(dut, f'grid_{r}_{c}') else f'grid_{r}'
                if has_signal(dut, f'grid_{r}_{c}'):
                    getattr(dut, f'grid_{r}_{c}').value = padded_grid[r][c]
                elif has_signal(dut, f'grid_{r}'):
                    # Packed array
                    val = 0
                    for b in range(GRID_COLS):
                        val |= (padded_grid[r][b] & 1) << b
                    getattr(dut, f'grid_{r}').value = val
        
        # Set capacity
        if has_signal(dut, 'capacity'):
            dut.capacity.value = capacity
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} failed: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1} failed: result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"Test {i+1} failed: expected {expected}, got {result}")
            failed += 1
        else:
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")