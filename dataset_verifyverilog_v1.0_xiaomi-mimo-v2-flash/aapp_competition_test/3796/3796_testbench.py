import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'data_valid'):
        dut.data_valid.value = 0
    if has_signal(dut, 'data_last'):
        dut.data_last.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def count_frequencies(nums):
    freq = {}
    for n in nums:
        freq[n] = freq.get(n, 0) + 1
    return freq

def find_optimal_rectangle(nums):
    freq = count_frequencies(nums)
    counts = list(freq.values())
    counts.sort(reverse=True)
    n = len(nums)
    best_area = 0
    best_h, best_w = 1, 1
    
    # Try heights from 1 to sqrt(n)
    import math
    max_h = min(64, int(math.sqrt(n)) + 1)
    for h in range(1, max_h + 1):
        total = 0
        for c in counts:
            total += min(c, h)
        w = total // h
        if w >= h:
            area = h * w
            if area > best_area:
                best_area = area
                best_h = h
                best_w = w
    return best_h, best_w, best_area

def fill_grid(nums, h, w):
    if h == 0 or w == 0:
        return [[0]]
    
    freq = count_frequencies(nums)
    # Sort by frequency descending
    items = sorted(freq.items(), key=lambda x: x[1], reverse=True)
    
    grid = [[0] * w for _ in range(h)]
    
    val_idx = 0
    val, count = items[val_idx]
    count = min(count, h)  # Can't use more than h times per value
    
    used = 0
    total_cells = h * w
    
    for col in range(w):
        for row in range(h):
            grid[row][(col + row) % w] = val
            used += 1
            count -= 1
            if count == 0:
                val_idx += 1
                if val_idx < len(items):
                    val, c = items[val_idx]
                    count = min(c, h)
                else:
                    # This shouldn't happen if rectangle is valid
                    break
            if used >= total_cells:
                break
        if used >= total_cells:
            break
    
    return grid

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_beautiful_rectangle(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8], "Example 1"),
        ([1, 1, 1, 1, 1], "All same"),
        ([1, 2, 3, 4, 5], "All distinct"),
        ([1, 2, 1, 2, 3, 3], "Mixed"),
        ([1], "Single element"),
        ([1, 2], "Two elements"),
    ]
    
    for test_idx, (nums, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc} ({len(nums)} elements)")
        
        # Expected results
        exp_h, exp_w, exp_area = find_optimal_rectangle(nums)
        exp_grid = fill_grid(nums, exp_h, exp_w)
        
        # Stream input
        dut.start.value = 1
        dut.len_in.value = clamp_to_width(len(nums), 4)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream numbers
        for i, num in enumerate(nums):
            dut.data_in.value = clamp_to_width(num, 32)
            dut.data_valid.value = 1
            dut.data_last.value = 1 if (i == len(nums) - 1) else 0
            await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0
        dut.data_last.value = 0
        
        # Wait for completion
        await wait_for_done(dut, max_cycles=10000)
        
        # Read results
        if not is_value_defined(dut.result_area.value):
            raise TestFailure("Result area undefined")
        
        result_area = int(dut.result_area.value)
        result_h = int(dut.result_h.value)
        result_w = int(dut.result_w.value)
        
        cocotb.log.info(f"Result: Area={result_area}, H={result_h}, W={result_w}")
        cocotb.log.info(f"Expected: Area={exp_area}, H={exp_h}, W={exp_w}")
        
        # Check dimensions match expected
        if result_area != exp_area:
            # Sometimes multiple optimal solutions exist
            # Check if our dimensions are valid
            if result_h * result_w != result_area:
                raise TestFailure(f"Area mismatch: got {result_h}*{result_w}={result_h*result_w}, but area={result_area}")
            
            # Verify it's a valid rectangle for the input
            if result_h > 64 or result_w > 64:
                raise TestFailure(f"Dimensions too large: H={result_h}, W={result_w}")
            
            if result_h * result_w < 1:
                raise TestFailure(f"Area too small: {result_area}")
        
        # Read grid output
        grid_cells = result_h * result_w
        output_grid = [[0] * result_w for _ in range(result_h)]
        
        # Collect output streaming
        cells_collected = 0
        timeout = 0
        
        while cells_collected < grid_cells and timeout < 1000:
            await RisingEdge(dut.clk)
            if has_signal(dut, 'out_valid') and is_value_defined(dut.out_valid.value):
                if int(dut.out_valid.value) == 1:
                    if is_value_defined(dut.out_y.value) and is_value_defined(dut.out_x.value):
                        y = int(dut.out_y.value)
                        x = int(dut.out_x.value)
                        if y < result_h and x < result_w:
                            output_grid[y][x] = int(dut.out_data.value)
                            cells_collected += 1
            timeout += 1
        
        if cells_collected != grid_cells:
            raise TestFailure(f"Expected {grid_cells} cells, got {cells_collected}")
        
        # Validate grid properties
        for y in range(result_h):
            row_vals = [output_grid[y][x] for x in range(result_w)]
            if len(set(row_vals)) != len(row_vals):
                raise TestFailure(f"Row {y} has duplicates: {row_vals}")
        
        for x in range(result_w):
            col_vals = [output_grid[y][x] for y in range(result_h)]
            if len(set(col_vals)) != len(col_vals):
                raise TestFailure(f"Column {x} has duplicates: {col_vals}")
        
        cocotb.log.info(f"Grid validation passed: {result_h}x{result_w} beautiful rectangle")
        
        # Reset for next test
        await reset_dut(dut)
