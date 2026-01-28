import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ROWS = 8
COLS = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_data(dut, data_2d):
    """Write 2D array to module. data_2d: list of rows, each row is list of COLS integers"""
    for r in range(ROWS):
        if r < len(data_2d):
            row = data_2d[r]
        else:
            row = [0] * COLS
        for c in range(COLS):
            val = row[c] if c < len(row) else 0
            # Access array as dut.data[r][c] or dut.data_rX_cY
            # Check naming convention - handle both
            attr_name = f'data_r{r}_c{c}'
            if hasattr(dut, attr_name):
                getattr(dut, attr_name).value = clamp_to_width(val, DATA_WIDTH)
            elif hasattr(dut, 'data') and hasattr(dut.data, '__getitem__'):
                # Try nested array
                try:
                    dut.data[r][c].value = clamp_to_width(val, DATA_WIDTH)
                except:
                    pass

async def run_test(dut, test_input, expected, description):
    """Run a single test case"""
    cocotb.log.info(f"Test: {description}")
    cocotb.log.info(f"Input rows: {len(test_input)}, Expected count: {expected}")
    
    # Write test data
    await write_data(dut, test_input)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, 100)
    
    # Read result
    if not is_value_defined(dut.count.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.count.value)
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"PASS: Result = {result}")
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_lists(dut):
    """Test counting of populated lists (rows)"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases based on original problem
    # Adapted: each inner list becomes a row with its elements as columns
    test_cases = [
        # Test 1: 4 populated rows
        ([
            [1, 3] + [0]*(COLS-2),   # Row 0: 2 values
            [5, 7] + [0]*(COLS-2),   # Row 1: 2 values
            [9, 11] + [0]*(COLS-2),  # Row 2: 2 values
            [13, 15, 17] + [0]*(COLS-3),  # Row 3: 3 values
            [0]*COLS,                # Row 4: empty
            [0]*COLS,                # Row 5: empty
            [0]*COLS,                # Row 6: empty
            [0]*COLS                 # Row 7: empty
        ], 4, "Four populated rows"),
        
        # Test 2: 3 populated rows
        ([
            [1, 2] + [0]*(COLS-2),
            [2, 3] + [0]*(COLS-2),
            [4, 5] + [0]*(COLS-2),
            [0]*COLS,
            [0]*COLS,
            [0]*COLS,
            [0]*COLS,
            [0]*COLS
        ], 3, "Three populated rows"),
        
        # Test 3: 2 populated rows
        ([
            [1, 0] + [0]*(COLS-2),
            [2, 0] + [0]*(COLS-2),
            [0]*COLS,
            [0]*COLS,
            [0]*COLS,
            [0]*COLS,
            [0]*COLS,
            [0]*COLS
        ], 2, "Two populated rows with zeros in row"),
        
        # Additional test: all empty
        ([
            [0]*COLS for _ in range(8)
        ], 0, "All empty rows"),
        
        # Additional test: all populated
        ([
            [1] + [0]*(COLS-1) for _ in range(8)
        ], 8, "All rows populated")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        try:
            await run_test(dut, inp, exp, desc)
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")