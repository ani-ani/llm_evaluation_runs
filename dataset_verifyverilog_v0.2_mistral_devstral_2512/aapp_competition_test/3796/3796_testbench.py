import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly
from cocotb.result import TestFailure
import random

def count_frequencies(input_list):
    freq = {}
    for x in input_list:
        freq[x] = freq.get(x, 0) + 1
    return freq

def solve_python(input_list):
    n = len(input_list)
    freq = count_frequencies(input_list)
    unique_counts = sorted(freq.values())
    
    best_area = 0
    best_h = 1
    best_w = 1
    
    # Try heights from min(n, 16) down to 1
    max_h = min(n, 16)
    for h in range(max_h, 0, -1):
        # Calculate how many cells we can fill with height h
        total = 0
        for c in unique_counts:
            total += min(c, h)
        
        w = total // h
        
        if w >= h and h * w > best_area:
            best_area = h * w
            best_h = h
            best_w = w
    
    return best_h, best_w, best_area

def generate_matrix_python(input_list, h, w):
    # Sort input to group identical numbers
    sorted_list = sorted(input_list)
    
    matrix = [[0] * w for _ in range(h)]
    
    idx = 0
    for i in range(h * w):
        if idx >= len(sorted_list):
            break
            
        val = sorted_list[idx]
        
        # Calculate position with diagonal offset
        # The Python algorithm uses specific offset: (x + y) % w for column, y for row
        # But we need to map linear index to (row, col) based on the diagonal method.
        # Let's use the standard diagonal filling logic:
        # k-th occurrence (0-indexed) of a number maps to:
        # row = k % h
        # col = (k + (k // h)) % w
        
        # However, the Python code in the prompt fills by iterating x (column), then y (row)
        # and uses ans[y][(x + y) % w] = num
        # This implies we need to fill column by column.
        
        # Let's replicate the exact filling strategy from the prompt:
        # Iterate values from least frequent to most (though prompt sorts by count ascending)
        # The prompt: nums, counts = zip(*sorted(cnt.items(), key=itemgetter(1)))
        # So it fills rarest numbers first.
        # Then it loops x from 0 to w-1, y from 0 to h-1.
        # If count runs out, move to next number.
        
        pass
    
    # Let's implement the prompt's filling logic explicitly
    cnt = count_frequencies(input_list)
    nums_counts = sorted(cnt.items(), key=lambda x: x[1])
    
    if not nums_counts:
        return matrix
        
    ans = [[0]*w for _ in range(h)]
    i = len(nums_counts) - 1
    num, count = nums_counts[i]
    count = min(h, count)
    
    for x in range(w):
        for y in range(h):
            ans[y][(x + y) % w] = num
            count -= 1
            if count == 0:
                if i > 0:
                    i -= 1
                    num, total_count = nums_counts[i]
                    count = min(h, total_count)
                else:
                    # No more numbers
                    return ans
    return ans

@cocotb.test()
async def test_beautiful_rectangle(dut):
    """Test the Beautiful Rectangle module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.n_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases (scaled down from prompt)
    test_cases = [
        ([3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8], "Case 1: Mixed"),
        ([1, 1, 1, 1, 1], "Case 2: All same"),
        ([10, 10], "Case 3: Two same"),
        ([1, 2, 3, 4, 5, 6, 7, 8], "Case 4: All unique"),
        ([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8], "Case 5: Pairs"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, name in test_cases:
        print(f"Running {name} with input {arr}")
        
        # Prepare input
        # Module expects 32 entries in data_in
        # We zero-pad if needed
        n = len(arr)
        data_packed = 0
        for i in range(32):
            val = arr[i] if i < n else 0
            data_packed |= (val << (i * 8))
            
        dut.data_in.value = data_packed
        dut.n_valid.value = n
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 500 # Max cycles
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= timeout:
            raise TestFailure(f"{name} timed out")
            
        # Read results
        h_hw = int(dut.rows.value)
        w_hw = int(dut.cols.value)
        
        # Get matrix
        matrix_hw = []
        for r in range(h_hw):
            row_vals = []
            for c in range(w_hw):
                # Extract byte from matrix_out
                # matrix_out is indexed [16][16][8]
                val = int(dut.matrix_out[r][c].value)
                row_vals.append(val)
            matrix_hw.append(row_vals)
            
        # Solve in Python
        h_py, w_py, area_py = solve_python(arr)
        matrix_py = generate_matrix_python(arr, h_py, w_py)
        
        print(f"  Hardware: {h_hw}x{w_hw} (Area: {h_hw*w_hw})")
        print(f"  Python:   {h_py}x{w_py} (Area: {h_py*w_py})")
        
        # Check dimensions
        if h_hw != h_py or w_hw != w_py:
            print(f"  HW Matrix:")
            for r in matrix_hw: print(f"    {r}")
            print(f"  Py Matrix:")
            for r in matrix_py: print(f"    {r}")
            raise TestFailure(f"{name} Dimensions mismatch. HW: {h_hw}x{w_hw}, Py: {h_py}x{w_py}")
            
        # Check area
        if h_hw * w_hw != area_py:
             raise TestFailure(f"{name} Area mismatch. HW: {h_hw*w_hw}, Py: {area_py}")
            
        # Check beauty (no duplicates in rows/cols)
        for r in range(h_hw):
            row_set = set()
            for c in range(w_hw):
                val = matrix_hw[r][c]
                if val == 0 and r * w_hw + c >= area_py:
                    continue # Ignore unused cells
                if val in row_set:
                    raise TestFailure(f"{name} Duplicate {val} in row {r}: {matrix_hw[r]}")
                row_set.add(val)
                
        for c in range(w_hw):
            col_set = set()
            for r in range(h_hw):
                val = matrix_hw[r][c]
                if val == 0 and r * w_hw + c >= area_py:
                    continue
                if val in col_set:
                    raise TestFailure(f"{name} Duplicate {val} in col {c}")
                col_set.add(val)
                
        # Check contents (multiset equality)
        # Flatten and count
        hw_vals = []
        for r in range(h_hw):
            for c in range(w_hw):
                hw_vals.append(matrix_hw[r][c])
        
        py_vals = []
        for r in range(h_py):
            for c in range(w_py):
                py_vals.append(matrix_py[r][c])
                
        if sorted(hw_vals) != sorted(py_vals):
            raise TestFailure(f"{name} Contents mismatch. HW: {sorted(hw_vals)}, Py: {sorted(py_vals)}")
            
        passed += 1
        print(f"  PASSED
")
        
    print(f"Summary: {passed}/{total} tests passed")
