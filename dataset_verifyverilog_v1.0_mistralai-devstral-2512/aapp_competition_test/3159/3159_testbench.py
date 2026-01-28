import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
H_MAX = 200
W_MAX = 200
GRID_SIZE = H_MAX * W_MAX
CLK_NS = 10

# Helper functions
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Python Logic Reference
def process_web_page_py(grid_str):
    lines = grid_str.strip().split('\n')
    h, w = map(int, lines[0].split())
    grid = [list(line.ljust(w)[:w]) for line in lines[1:]]
    
    # Detect frames (borders of +)
    frames = [] # (r1, c1, r2, c2, area)
    
    for r in range(h):
        for c in range(w):
            if grid[r][c] == '+':
                # Check if this is top-left corner
                # Look right for top border
                # Look down for left border
                # But simplest is to check if we have a rectangle starting here
                # We need to ensure we don't double count or miss
                # Let's just brute force scan for valid rectangles
                pass
    
    # Better frame detection: 
    # Find all '+' positions. 
    # For each '+', assume it's top-left. 
    # Scan right for '+' in same row. 
    # Scan down for '+' in same col.
    # Check intersection for bottom-right.
    # Check borders.
    
    detected = []
    for r1 in range(h):
        for c1 in range(w):
            if grid[r1][c1] == '+':
                # Scan right
                for c2 in range(c1 + 2, w): # at least 3 wide (c1, ..., c2)
                    if grid[r1][c2] == '+':
                        # Scan down at c1
                        for r2 in range(r1 + 2, h):
                            if grid[r2][c1] == '+':
                                # Check bottom-right corner
                                if grid[r2][c2] == '+':
                                    # Validate borders
                                    valid = True
                                    # Top edge
                                    for cc in range(c1+1, c2):
                                        if grid[r1][cc] != '-': valid = False
                                    # Bottom edge
                                    for cc in range(c1+1, c2):
                                        if grid[r2][cc] != '-': valid = False
                                    # Left edge
                                    for rr in range(r1+1, r2):
                                        if grid[rr][c1] != '|': valid = False
                                    # Right edge
                                    for rr in range(r1+1, r2):
                                        if grid[rr][c2] != '|': valid = False
                                    
                                    if valid:
                                        # Check no touching other frames (simplified check: corners)
                                        # The problem says "Borders of different images will not be adjacent".
                                        # We assume input is valid. We just collect.
                                        detected.append((r1, c1, r2, c2))
    
    # Deduplicate (nested rects will be found multiple times if we scan every +)
    # Actually, if we iterate strictly top-left, we get unique rectangles.
    frames = []
    for (r1, c1, r2, c2) in detected:
        # Check if this is strictly top-left (no + above/left inside the rect? No, just take unique)
        area = (r2 - r1 + 1) * (c2 - c1 + 1)
        frames.append((r1, c1, r2, c2, area))
    
    # Sort by area ascending
    frames.sort(key=lambda x: x[4])
    
    # Identify banned chars
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!,. ")
    
    removed_frames = set()
    
    # For every pixel, if banned, find smallest frame containing it
    for r in range(h):
        for c in range(w):
            if grid[r][c] not in allowed:
                # Find smallest frame containing (r, c)
                for f_idx, (r1, c1, r2, c2, area) in enumerate(frames):
                    if r1 <= r <= r2 and c1 <= c <= c2:
                        removed_frames.add(f_idx)
                        break # Found smallest
    
    # Generate output
    out_grid = [list(row) for row in grid]
    for idx in removed_frames:
        r1, c1, r2, c2, _ = frames[idx]
        for r in range(r1, r2 + 1):
            for c in range(c1, c2 + 1):
                out_grid[r][c] = ' '
    
    # Format string
    res = ""
    for row in out_grid:
        res += "".join(row) + "\n"
    return res[:-1] # remove last newline

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_ads_removal(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'din_valid'): dut.din_valid.value = 0
        await Timer(2 * CLK_NS, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test Case 1: Nested Image with Ban
    h, w = 7, 7
    # Frame 1: Outer (0,0) to (6,6). Area 49.
    # Frame 2: Inner (2,2) to (4,4). Area 9.
    # Inner frame has '=' which is banned.
    # Smallest frame containing '=' is Inner (Area 9). So Inner should be removed.
    # Outer remains (with spaces inside where Inner was).
    grid = [
        "+++++++",
        "+     +",
        "+ +++ +", # Row 2: Inner starts
        "+ +=+ +", # Row 3: Banned '=' at col 3
        "+ +++ +", # Row 4: Inner ends
        "+     +",
        "+++++++"
    ]
    
    # Generate input stream
    # Input: H, W, then H*W chars
    # We need to feed H, W first? 
    # The problem takes H, W as first line. 
    # Our module likely expects H, W or processes fixed size.
    # Let's assume the module processes a fixed 200x200 grid, but we feed only relevant data.
    # Or the module takes H, W inputs.
    
    # Let's assume the spec: 
    # Inputs: clk, rst_n, start, din, din_valid
    # Start triggers processing. 
    # We need to send 40,000 chars. But we only care about 7x7.
    # We will send H=7, W=7. 
    # But wait, the problem input is "H W\nGrid...".
    # The HDL module should be robust. 
    # Let's refine the module spec to take H and W as inputs (8 bits).
    # And then consume H*W characters.
    
    # However, to keep it simple for the benchmark, let's assume fixed 200x200.
    # We will pad the grid to 200x200 with spaces.
    
    padded_grid = []
    for r in range(h):
        padded_grid.append(list(grid[r].ljust(200)))
    for r in range(h, 200):
        padded_grid.append([' '] * 200)
    
    # Flatten
    stream = []
    for r in range(200):
        for c in range(200):
            stream.append(ord(padded_grid[r][c]))
    
    cocotb.log.info(f"Starting test case 1: {h}x{w} nested frame with ban")
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Feed data
    # Assuming din_valid is used. If not, assume data is accepted every cycle.
    if has_signal(dut, 'din_valid'):
        dut.din_valid.value = 1
    
    # We need to drive din. 
    # But wait, the spec says "Web pages are littered with ads".
    # The Python code takes H, W then grid.
    # My module spec in prompt should handle H, W or be fixed.
    # Let's stick to the prompt's fixed 200x200 assumption for simplicity in HDL.
    # The testbench will send 40,000 characters.
    
    for char in stream:
        dut.din.value = clamp_to_width(char, DATA_WIDTH)
        await RisingEdge(dut.clk)
        
    if has_signal(dut, 'din_valid'):
        dut.din_valid.value = 0
    
    # Wait for done
    max_cycles = 100000 # 100k cycles for heavy processing
    done_found = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_found = True
            break
        # Also check dout_valid
        if has_signal(dut, 'dout_valid') and is_value_defined(dut.dout_valid.value) and int(dut.dout_valid.value) == 1:
            # We are in output phase. Capture data.
            pass
    
    if not done_found:
        raise TestFailure(f"Timeout after {max_cycles} cycles")

    # Read Output
    # Assuming output is streamed out 40,000 cycles after start, or parallel read.
    # Let's assume the module streams output on `dout` when `dout_valid` is high.
    # Or we read from memory interface.
    # The prompt says: Output the web page. 
    # Let's assume a simple interface: 
    # Process complete. Read result from `dout` or memory interface.
    # Let's refine the module to have a `read_addr` and `read_data` output for verification.
    
    # Actually, for the testbench, we can just read the internal memory if possible (using层次化访问) or check output stream.
    
    # Let's assume the module has a read interface:
    # input read_en, input [11:0] read_addr, output [7:0] read_data
    # Or it streams out.
    # Given the complexity, let's assume it streams out 40,000 cycles after loading.
    
    # Re-reading the prompt "Output the web page with all the ads removed."
    # It implies we need to produce the whole grid.
    
    # Let's adjust the testbench to read the result from a streaming interface.
    # If the module doesn't have a streaming output, we might need to simulate a memory read.
    # 
    # Let's assume the prompt's module has:
    # output [7:0] dout
    # output dout_valid
    # output done
    # 
    # Behavior: 
    # 1. Load phase (din consumed)
    # 2. Process phase
    # 3. Output phase (dout streams the result, 40,000 cycles)
    # 4. Done pulse
    
    # Wait for output phase
    await Timer(1, units='us') # Give some buffer
    
    output_grid = []
    for _ in range(GRID_SIZE):
        if has_signal(dut, 'dout_valid'):
             while not (is_value_defined(dut.dout_valid.value) and int(dut.dout_valid.value) == 1):
                 await RisingEdge(dut.clk)
        # Read dout
        if has_signal(dut, 'dout'):
            val = int(dut.dout.value)
            output_grid.append(chr(val))
            await RisingEdge(dut.clk)
        else:
            raise TestFailure("dout signal not found")
    
    # Reconstruct 200x200 grid
    result_grid_str = ""
    for r in range(h):
        row_str = ""
        for c in range(w):
            idx = r * 200 + c
            if idx < len(output_grid):
                row_str += output_grid[idx]
        result_grid_str += row_str + "\n"
    
    result_grid_str = result_grid_str.strip()
    
    # Verify
    expected = process_web_page_py(f"{h} {w}\n" + "\n".join(grid))
    
    if result_grid_str != expected:
        cocotb.log.error(f"Mismatch:\nGot:\n{result_grid_str}\nExpected:\n{expected}")
        raise TestFailure("Output mismatch")
    else:
        cocotb.log.info("Test case 1 passed")

    # Test Case 2: Sample Input 2 (All ads removed)
    h, w = 7, 7
    grid = [
        "+++++++",
        "+  =  +",
        "+ +++ +",
        "+ + + +",
        "+ +++ +",
        "+     +",
        "+++++++"
    ]
    # Logic: Inner 3x3 frame has no banned chars (it has spaces and +). 
    # Wait, inner frame has '+' borders. Inner interior is spaces. 
    # Outer frame has '=' banned at (1, 3).
    # Outer frame area = 49. 
    # Inner frame area = 9 (if valid). 
    # Is Inner frame valid? It has '+' borders. Inner interior is empty. Valid.
    # '=' is inside Outer. Is it inside Inner? No.
    # So Outer frame contains banned char. Outer frame removed.
    # Result: All spaces.
    
    # Pad
    padded_grid = []
    for r in range(h):
        padded_grid.append(list(grid[r].ljust(200)))
    for r in range(h, 200):
        padded_grid.append([' '] * 200)
    
    stream = []
    for r in range(200):
        for c in range(200):
            stream.append(ord(padded_grid[r][c]))
    
    cocotb.log.info(f"Starting test case 2: {h}x{w} single ad")
    
    # Reset for new run (assuming module needs reset or start pulse)
    # In real hardware, we might need to reset state.
    # Let's toggle reset.
    dut.rst_n.value = 0
    await Timer(2 * CLK_NS, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    if has_signal(dut, 'din_valid'):
        dut.din_valid.value = 1
    
    for char in stream:
        dut.din.value = clamp_to_width(char, DATA_WIDTH)
        await RisingEdge(dut.clk)
        
    if has_signal(dut, 'din_valid'):
        dut.din_valid.value = 0
        
    # Wait for output
    done_found = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure(f"Timeout in Test 2 after {max_cycles} cycles")

    output_grid = []
    for _ in range(GRID_SIZE):
        if has_signal(dut, 'dout_valid'):
             while not (is_value_defined(dut.dout_valid.value) and int(dut.dout_valid.value) == 1):
                 await RisingEdge(dut.clk)
        
        if has_signal(dut, 'dout'):
            val = int(dut.dout.value)
            output_grid.append(chr(val))
            await RisingEdge(dut.clk)
    
    result_grid_str = ""
    for r in range(h):
        row_str = ""
        for c in range(w):
            idx = r * 200 + c
            row_str += output_grid[idx]
        result_grid_str += row_str + "\n"
    result_grid_str = result_grid_str.strip()
    
    expected = process_web_page_py(f"{h} {w}\n" + "\n".join(grid))
    
    if result_grid_str != expected:
        cocotb.log.error(f"Mismatch:\nGot:\n{result_grid_str}\nExpected:\n{expected}")
        raise TestFailure("Output mismatch Test 2")
    else:
        cocotb.log.info("Test case 2 passed")
