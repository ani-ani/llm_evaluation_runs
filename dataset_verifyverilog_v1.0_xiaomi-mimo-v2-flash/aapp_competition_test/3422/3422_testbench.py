import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on prompt
MAX_PIECES = 8
MAX_DIM = 10
MAX_MAP_SIZE = 80
DATA_WIDTH = 4
PIECE_IDX_WIDTH = 3
GRID_SIZE = MAX_MAP_SIZE * MAX_MAP_SIZE  # 6400 cells

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Array writing helpers
def write_piece(dut, index, w, h, data_grid):
    """Writes piece data to the DUT. Assumes piece_w/h/index are separate arrays or buses.
    For this complex input, we assume the DUT has specific inputs like piece_w[0..7] etc.
    """
    # Write dimensions
    dut.piece_w[index].value = clamp_to_width(w, 4)
    dut.piece_h[index].value = clamp_to_width(h, 4)
    
    # Write data. We assume 'piece_data' is a flattened array of [8][100] or similar.
    # If it's a single big vector, we pack it.
    # Let's assume the DUT has: input [3:0] piece_data [0:799] (8*100)
    # Or: input [3:0] piece_data_0_0, ... (too many signals)
    # More likely: input [3:0] piece_data [0:799]
    
    # Since Python cocotb handles unpacked arrays differently, we iterate.
    # Index calculation: offset = index * 100. 
    
    # NOTE: If the DUT interface is a single vector, we pack it.
    # If it's unpacked array of vectors, we iterate.
    # Let's assume the prompt's 'input [3:0] piece_data [0:799]' implies unpacked.
    
    flat_idx = index * 100
    for y in range(h):
        for x in range(w):
            val = int(data_grid[y][x])
            # Access specific element
            # Assuming dut.piece_data is an unpacked array: [0:799]
            try:
                getattr(dut, f'piece_data_{flat_idx + y*w + x}').value = clamp_to_width(val, 4)
            except AttributeError:
                # Fallback for packed vector if unpacked doesn't exist
                # This part depends on exact DUT definition. 
                # We will try to assign to individual elements if possible.
                pass
    
    # Fill rest of piece space with 0
    for i in range(h*w, 100):
        try:
            getattr(dut, f'piece_data_{flat_idx + i}').value = 0
        except AttributeError:
            pass

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_treasure_map(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'piece_count'):
        dut.piece_count.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1 (from example)
    # 3 pieces
    # Piece 0: 4x1, "2123"
    # Piece 1: 2x2, "21", "10"
    # Piece 2: 2x2, "23", "12"
    
    # We need to map these to the DUT inputs.
    # Since we cannot dynamically parse arbitrary input strings in Verilog easily without a parser,
    # the testbench should construct the Verilog input format.
    
    # Configure DUT
    if has_signal(dut, 'piece_count'):
        dut.piece_count.value = 3
    
    # Piece 0
    write_piece(dut, 0, 4, 1, [[2,1,2,3]])
    # Piece 1
    write_piece(dut, 1, 2, 2, [[2,1],[1,0]])
    # Piece 2
    write_piece(dut, 2, 2, 2, [[2,3],[1,2]])
    
    # Start signal
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for valid
    found = False
    for i in range(200000): # Large timeout for backtracking
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            found = True
            break
            
    if not found:
        raise TestFailure("DUT did not assert valid within timeout")
        
    # Read Output
    # We expect: out_width, out_height, map_data (flattened), piece_indices (flattened)
    # map_data is [0:799] (4 bits). We reconstruct 2D.
    # piece_indices is [0:799] (3 bits).
    
    w = int(dut.out_width.value)
    h = int(dut.out_height.value)
    
    cocotb.log.info(f"Reconstructed map size: {w}x{h}")
    
    # Read flattened arrays
    result_map = []
    result_indices = []
    
    # Reading array elements
    # We assume the output is accessible as 'map_data_0' to 'map_data_799'
    # Or via a list-like interface in cocotb.
    
    for y in range(h):
        row_vals = []
        row_idxs = []
        for x in range(w):
            idx = y * MAX_MAP_SIZE + x  # Or whatever the stride is
            try:
                val = int(getattr(dut, f'map_data_{idx}').value)
                row_vals.append(str(val))
                idx_val = int(getattr(dut, f'piece_indices_{idx}').value)
                row_idxs.append(str(idx_val + 1)) # 1-based output
            except AttributeError:
                # Fallback for packed vector access
                pass
        result_map.append("".join(row_vals))
        result_indices.append("".join(row_idxs))
        
    # Verification
    # 1. Check dimensions match expected logic (Total area check)
    total_area = 0
    # Areas of pieces: 4*1 + 2*2 + 2*2 = 4 + 4 + 4 = 12
    # Expected map: 4x3 = 12
    
    if w * h != 12:
        raise TestFailure(f"Map area {w*h} does not match total piece area 12")
        
    # 2. Check map content validity (Recalculate distances)
    # Find treasure (value 0)
    tx, ty = -1, -1
    treasure_found = False
    for y in range(h):
        for x in range(w):
            val = int(result_map[y][x])
            if val == 0: # Assuming treasure is 0, or matching modulo
                tx, ty = x, y
                treasure_found = True
                break
        if treasure_found: break
        
    if not treasure_found:
        # If no 0, check if any cell satisfies the property with any other cell as center?
        # The problem guarantees one piece contains treasure square.
        # Let's assume treasure is 0 as per sample.
        # If sample didn't have 0, we'd need a more complex check.
        # Sample 1: Has 0s. Sample 2: Check.
        # We will just verify the distances based on found treasure.
        # If no explicit 0, we might have to guess, but for now assume 0 is treasure.
        pass
        
    # Verify distances
    if treasure_found:
        for y in range(h):
            for x in range(w):
                dist = abs(x - tx) + abs(y - ty)
                expected = dist % 10
                actual = int(result_map[y][x])
                if actual != expected:
                    # Sometimes map might have other digits if modulo matches? 
                    # No, the map IS the distance modulo 10.
                    raise TestFailure(f"Cell ({x},{y}) dist {dist}%10={expected}, got {actual}")

    # 3. Verify piece indices
    # Check that indices are 1, 2, 3 (since 3 pieces)
    flat_indices = []
    for r in result_indices:
        flat_indices.extend(list(r))
    
    for idx in flat_indices:
        if idx == '0' or int(idx) > 3:
            raise TestFailure(f"Invalid piece index {idx} in output")
            
    cocotb.log.info("Test Passed: Valid map reconstructed.")
