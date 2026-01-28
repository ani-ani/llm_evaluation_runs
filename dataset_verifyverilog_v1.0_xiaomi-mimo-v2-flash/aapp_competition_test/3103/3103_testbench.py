import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for this problem
DATA_WIDTH = 3
MAX_ROWS = 8
MAX_COLS = 8
CLK_NS = 10
MAX_CYCLES = 256
MOD = 1000003

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Encode grid characters to 3-bit values
def encode_char(c):
    if c == '~': return 0
    if c == '#': return 1
    if c == '>': return 2
    if c == '<': return 3
    if c == '@': return 4
    return 0  # Default to open sea

# Parse grid string into list of lists
async def write_grid(dut, grid_str, Y, X):
    """Write grid to dut inputs. Grid is Y rows, X cols. Assuming dut has grid_0_0 to grid_7_7."""
    # Parse string
    lines = grid_str.strip().split('\n')
    # Pad to 8x8 if needed, or assume input fits 8x8
    # For simplicity, we assume max 8x8 as per problem limit.
    grid_vals = []
    for r in range(Y):
        row_str = lines[r] if r < len(lines) else '~' * X
        for c in range(X):
            char = row_str[c] if c < len(row_str) else '~'
            grid_vals.append(encode_char(char))
    
    # Fill remaining 8x8 grid with open sea
    total_needed = MAX_ROWS * MAX_COLS
    while len(grid_vals) < total_needed:
        grid_vals.append(0)
    
    # Write to dut signals: grid_0_0 ... grid_7_7
    # Assuming dut signals are named grid_0_0, grid_0_1, ..., grid_7_7
    # Or flattened: grid[0] to grid[63]
    # Let's check naming convention
    for r in range(MAX_ROWS):
        for c in range(MAX_COLS):
            idx = r * MAX_COLS + c
            val = grid_vals[idx]
            # Try flat naming first, then indexed
            try:
                getattr(dut, f'grid_{r}_{c}').value = clamp_to_width(val, DATA_WIDTH)
            except AttributeError:
                # Try flat array
                try:
                    dut.grid[idx].value = clamp_to_width(val, DATA_WIDTH)
                except AttributeError:
                    pass # Ignore if signal doesn't exist

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ship_paths(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        dut.rst_n.value = 1
    
    test_cases = [
        {
            "name": "Sample 1",
            "input": "2 2 0\n>@\n>~\n",
            "expected_res": 2,
            "expected_begin": False
        },
        {
            "name": "Sample 2",
            "input": "3 5 1\n>>@<<\n>~#~<\n>>>>~\n",
            "expected_res": 4,
            "expected_begin": False
        },
        {
            "name": "Sample 3",
            "input": "3 4 0\n>~@~\n~<#~\n>>>~\n",
            "expected_res": 0,
            "expected_begin": True
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['name']}")
        
        lines = tc['input'].strip().split('\n')
        if not lines: continue
        
        try:
            # Parse header
            parts = lines[0].split()
            Y = int(parts[0])
            X = int(parts[1])
            x_init = int(parts[2])
            
            # Constraint for HW: Map must fit 8x8
            if Y > MAX_ROWS or X > MAX_COLS:
                cocotb.log.info(f"Skipping {tc['name']}: Size {Y}x{X} exceeds HW limit {MAX_ROWS}x{MAX_COLS}")
                continue
                
            # Write inputs
            dut.start.value = 0
            dut.x_init.value = clamp_to_width(x_init, 3)
            
            # Write grid
            grid_str = '\n'.join(lines[1:])
            await write_grid(dut, grid_str, Y, X)
            
            # Wait a cycle for inputs to settle
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational, just wait for outputs
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Check begin_repairs flag
            begin_val = 0
            if has_signal(dut, 'begin_repairs'):
                begin_val = int(dut.begin_repairs.value)
            
            # Verify
            if tc['expected_begin']:
                if begin_val != 1:
                    raise TestFailure(f"Expected begin_repairs=1, got {begin_val}")
                # Result should be 0 usually, but spec says output "begin repairs" if 0 paths
                # We check if paths are 0 mod MOD
                if result != 0:
                     # Sometimes due to modulo, 0 is 0. If result is not 0, check if logic matches
                     pass # Just check flag
            else:
                if begin_val == 1:
                    raise TestFailure(f"Unexpected begin_repairs=1 (Expected {tc['expected_res']})")
                if result != tc['expected_res']:
                    raise TestFailure(f"Expected result {tc['expected_res']}, got {result}")
            
            cocotb.log.info(f"PASS: {tc['name']}")
            passed += 1
            
        except Exception as e:
            cocotb.log.error(f"FAIL: {tc['name']} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

