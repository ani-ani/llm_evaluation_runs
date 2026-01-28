import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 2
GRID_R = 4
GRID_C = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# Cell encoding
CELL_FLOOR = 0
CELL_X = 1
CELL_L = 2

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

def pack_grid(grid_string):
    lines = grid_string.strip().split('\n')
    if len(lines) > 1:
        lines = lines[1:]
    packed = 0
    bit_pos = 0
    for r in range(min(len(lines), GRID_R)):
        row = lines[r][:GRID_C]
        for c in range(min(len(row), GRID_C)):
            char = row[c]
            if char == '.':
                val = CELL_FLOOR
            elif char == 'X':
                val = CELL_X
            elif char == 'L':
                val = CELL_L
            else:
                val = CELL_FLOOR
            packed |= (val & 0x3) << bit_pos
            bit_pos += 2
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tram_explosion(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (
            "4 4\n.LX.\n.X..\n....\n.L..\n",
            1,
            "Sample 1"
        ),
        (
            "4 4\n.XLX\n.X..\n...L\n.X..\n",
            2,
            "Sample 2"
        ),
        (
            "7 7\n...X.X.\nXL....L\n.......\n...L...\n.....X.\n.....L.\n...X...\n",
            1,
            "Sample 3"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            packed = pack_grid(grid_str)
            dut.grid.value = packed
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.explosions.value):
                raise TestFailure("Explosions output undefined")
            
            result = int(dut.explosions.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: explosions = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Summary: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")