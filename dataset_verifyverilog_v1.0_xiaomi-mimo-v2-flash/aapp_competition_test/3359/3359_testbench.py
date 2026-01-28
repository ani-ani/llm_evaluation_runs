import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
GRID_ROWS = 16
GRID_COLS = 16
CLK_NS = 10
MAX_CYCLES = 10000

# Helper functions from template
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_grid(dut, grid):
    """Write 16x16 grid to flattened img_in array"""
    flat = []
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            flat.append(grid[r][c])
    
    # img_in is a packed array or individual signals
    if has_signal(dut, 'img_in'):
        # Try individual element access: img_in_0, img_in_1...
        for i in range(256):
            attr_name = f'img_in_{i}'
            if has_signal(dut, attr_name):
                getattr(dut, attr_name).value = clamp_to_width(flat[i], DATA_WIDTH)
            else:
                # Fallback: assume it's an array port
                try:
                    dut.img_in[i].value = clamp_to_width(flat[i], DATA_WIDTH)
                except:
                    # Last resort: pack if needed (not expected here)
                    pass
    else:
        # Try individual ports
        for i in range(256):
            attr_name = f'img_in_{i}'
            if has_signal(dut, attr_name):
                getattr(dut, attr_name).value = clamp_to_width(flat[i], DATA_WIDTH)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_stellar_bodies(dut):
    """Test connected component counting on 16x16 grids"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: 16x16 grids with expected component counts
    test_cases = []
    
    # Case 1: Simple isolated pixels (2 components)
    case1 = [[0]*16 for _ in range(16)]
    case1[2][2] = 255  # Component 1
    case1[10][10] = 255  # Component 2
    test_cases.append((case1, 2, "Two isolated stars"))
    
    # Case 2: Connected blob (1 component)
    case2 = [[0]*16 for _ in range(16)]
    case2[5][5] = 255
    case2[5][6] = 255
    case2[6][5] = 255
    test_cases.append((case2, 1, "One connected blob"))
    
    # Case 3: Edge case - full grid (1 component if connected)
    case3 = [[255]*16 for _ in range(16)]
    test_cases.append((case3, 1, "Full white grid"))
    
    # Case 4: Empty grid (0 components)
    case4 = [[0]*16 for _ in range(16)]
    test_cases.append((case4, 0, "All black"))
    
    # Case 5: Cross pattern (1 component)
    case5 = [[0]*16 for _ in range(16)]
    for i in range(16):
        case5[7][i] = 255
        case5[i][7] = 255
    test_cases.append((case5, 1, "Cross pattern"))
    
    passed = failed = 0
    
    for i, (grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write grid
            await write_grid(dut, grid)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, 5000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")