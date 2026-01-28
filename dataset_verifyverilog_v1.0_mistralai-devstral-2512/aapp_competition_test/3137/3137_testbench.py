import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except: return False

def safe_int(v, default=0):
    try: return int(v)
    except: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_grid(grid):
    # grid is 8x8 list of ints (0-9)
    # Returns a list of 64 integers
    flat = []
    for row in grid:
        for val in row:
            flat.append(clamp_to_width(val, 4))
    # Pad if smaller than 64 (shouldn't happen with 8x8)
    while len(flat) < 64:
        flat.append(0)
    return flat

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bacteria_simulation(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Detect inputs
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(2 * CLK_NS, units='ns')
        await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(1, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(1, units='ns')
    
    # Test cases from Python example
    test_cases = [
        { # Sample 1
            "N": 3, "M": 3, "K": 1,
            "trap": (2, 2),
            "bacteria": [
                {"start": (1, 1, 'R'), "grid": [[0,1,0],[0,0,0],[0,0,0]]}
            ],
            "expected": 2
        },
        { # Sample 2
            "N": 3, "M": 4, "K": 2,
            "trap": (2, 2),
            "bacteria": [
                {"start": (3, 4, 'R'), "grid": [[2,3,2,7],[6,0,0,9],[2,1,1,2]]},
                {"start": (3, 2, 'R'), "grid": [[1,3,1,0],[2,1,0,1],[1,3,0,1]]}
            ],
            "expected": 7
        },
        { # Sample 3 (Longer)
            "N": 4, "M": 4, "K": 3,
            "trap": (4, 3),
            "bacteria": [
                {"start": (1, 1, 'U'), "grid": [[1,0,0,1],[0,2,4,0],[3,3,2,2],[2,3,2,7]]},
                {"start": (1, 3, 'L'), "grid": [[9,5,2,1],[2,3,9,0],[3,0,2,0],[2,4,2,1]]},
                {"start": (2, 2, 'D'), "grid": [[3,3,9,7],[2,0,1,3],[1,1,0,2],[7,3,0,2]]}
            ],
            "expected": 295
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}")
        
        # Map directions
        dir_map = {'U': 0, 'R': 1, 'D': 2, 'L': 3}
        
        # Load inputs
        # Assuming inputs are indexed: trap_row, trap_col, start_row_i, start_col_i, start_dir_i, grid_i
        # We need to handle the array structure. Since Verilog ports for 2D arrays are complex,
        # we assume a flattened interface or access logic in the testbench based on the dut structure.
        
        # Set trap (scaled to 0-7 range, input is 1-based)
        trap_r = tc['trap'][0] - 1
        trap_c = tc['trap'][1] - 1
        if has_signal(dut, 'trap_row'): dut.trap_row.value = clamp_to_width(trap_r, 4)
        if has_signal(dut, 'trap_col'): dut.trap_col.value = clamp_to_width(trap_c, 4)
        
        # Set bacteria data
        for i in range(tc['K']):
            b = tc['bacteria'][i]
            sr = b['start'][0] - 1
            sc = b['start'][1] - 1
            sd = dir_map[b['start'][2]]
            
            # Set start positions and direction
            if has_signal(dut, f'start_row_{i}'): dut.__getattr__(f'start_row_{i}').value = clamp_to_width(sr, 4)
            if has_signal(dut, f'start_col_{i}'): dut.__getattr__(f'start_col_{i}').value = clamp_to_width(sc, 4)
            if has_signal(dut, f'start_dir_{i}'): dut.__getattr__(f'start_dir_{i}').value = clamp_to_width(sd, 2)
            
            # Set grid
            # Handle grid as 64 signals or a flattened array. 
            # If it's a standard array: dut.grid_i[0..63].value
            # If individual signals: dut.grid_i_0...
            flat_grid = pack_grid(b['grid'])
            for j in range(64):
                sig_name = f'grid_{i}_{j}'
                if has_signal(dut, sig_name):
                    dut.__getattr__(sig_name).value = flat_grid[j]
                elif has_signal(dut, 'grid_i') and hasattr(dut.grid_i, '__getitem__'):
                     # Try accessing array element
                     try:
                         dut.grid_i[i][j].value = flat_grid[j]
                     except:
                         pass
        
        # Start simulation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational? Unlikely for this complexity. Assume sequential.
            await Timer(1, units='ns')
            
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns') # Combinational fallback
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {tc_idx + 1}: Timeout waiting for done")
            
        # Check result
        if has_signal(dut, 'result'):
            res_val = int(dut.result.value)
            # Handle signed result if -1 is represented as two's complement
            if res_val >= (1 << 15): # Assuming 16-bit result
                res_val = res_val - (1 << 16)
            
            if res_val != tc['expected']:
                 raise TestFailure(f"Test {tc_idx + 1}: Expected {tc['expected']}, got {res_val}")
        else:
            raise TestFailure("Result signal not found")

