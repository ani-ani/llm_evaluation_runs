import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_N = 8
CLK_NS = 10
MAX_CYCLES = 500

# Helpers
try:
    int(0)
    def is_value_defined(v): return True
except ValueError:
    def is_value_defined(v): return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Grid packing helper (Row Major, Bit 0 is R0C0)
def pack_grid(grid_list, n):
    packed = 0
    for r in range(n):
        for c in range(n):
            # grid_list[r][c] is 0 for '.', 1 for 'E' (or True/False)
            val = 1 if grid_list[r][c] == 'E' or grid_list[r][c] is True else 0
            bit_idx = r * n + c
            packed |= (val << bit_idx)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(cycles * CLK_NS, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    clk_present = has_signal(dut, 'clk')
    for _ in range(max_cycles):
        if clk_present:
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_purification(dut):
    # Setup clock if present
    clk_present = has_signal(dut, 'clk')
    if clk_present:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # --- Helper to convert grid string list to 64-bit int ---
    def prepare_grid(input_str_list, n):
        grid_matrix = []
        for row in input_str_list:
            row_chars = list(row.strip())
            # Ensure length matches n
            row_chars = row_chars[:n]
            while len(row_chars) < n:
                row_chars.append('.')
            grid_matrix.append(row_chars)
        return pack_grid(grid_matrix, n)

    # --- Test Cases ---
    # Case 1: Full Rows of E (Impossible)
    # Input: 3x3
    # EEE
    # E..
    # E.E
    # Row 0 is full E. Column 0 is full E. -> Impossible
    test_cases = []
    
    # Case 1: Impossible (Row 0 full E, Col 0 full E)
    # n=3
    # EEE
    # E..
    # E.E
    # 0 means safe '.', 1 means E
    grid_1 = [
        [1,1,1],
        [1,0,0],
        [1,0,1]
    ]
    test_cases.append({
        'n': 3,
        'grid': grid_1,
        'expected_imp': True,
        'desc': 'Full row 0 and full col 0'
    })
    
    # Case 2: Valid - Row solution
    # n=3
    # .E.
    # E.E
    # .E.
    # Every row has a '.', so pick one from each row.
    grid_2 = [
        [0,1,0],
        [1,0,1],
        [0,1,0]
    ]
    # Expected: (1,1), (2,2), (3,1) -> Index 0-based: (0,0), (1,1), (2,0)
    test_cases.append({
        'n': 3,
        'grid': grid_2,
        'expected_imp': False,
        'expected_outputs': [(0,0), (1,1), (2,0)],
        'desc': 'Valid Row Solution'
    })
    
    # Case 3: Valid - Column solution
    # n=3
    # .EE
    # .EE
    # .EE
    # Rows 0 and 1 have '.' in col 0. Row 2 has '.' in col 0.
    # Actually every column? No, Col 0 has all '.', Col 1 and 2 have all E.
    # Logic: If a row is full E, we CANNOT use row solution.
    # In this grid: Row 0 is not full E. Row 1 is not full E. Row 2 is not full E.
    # Wait, let's use a case where Row Solution fails (full E row exists) but Col solution works.
    # n=3
    # .EE (Row 0: safe col 0)
    # .EE (Row 1: safe col 0)
    # EEE (Row 2: full E -> Row Solution Impossible)
    # Col 0: ., ., E -> Has safe cells.
    # Col 1: E, E, E -> Full E.
    # Col 2: E, E, E -> Full E.
    # Wait, if Col 1 is full E and Col 2 is full E, Col Solution fails too.
    # 
    # Correct Case 3:
    # n=3
    # EE. (Row 0: safe col 2)
    # EE. (Row 1: safe col 2)
    # EEE (Row 2: full E) -> Row Solution Impossible.
    # Col 0: E, E, E -> Full E
    # Col 1: E, E, E -> Full E
    # Col 2: ., ., E -> Has safe cells.
    # So Col Solution works (pick one from each column).
    # Wait, Column Solution requires EVERY column to have a safe cell.
    # In this example, Col 0 and Col 1 are full E.
    # So Column Solution is also impossible.
    # 
    # Let's construct a valid Column-only case:
    # n=3
    # ...
    # EEE
    # EEE
    # Row 1 is full E. Row 2 is full E. -> Row Solution Impossible.
    # Col 0: ., E, E -> Safe
    # Col 1: ., E, E -> Safe
    # Col 2: ., E, E -> Safe
    # Column Solution: Pick (0,0), (0,1), (0,2).
    grid_3 = [
        [0,0,0],
        [1,1,1],
        [1,1,1]
    ]
    test_cases.append({
        'n': 3,
        'grid': grid_3,
        'expected_imp': False,
        'expected_outputs': [(0,0), (0,1), (0,2)], # 1-based output: 1 1, 1 2, 1 3
        'desc': 'Valid Column Solution'
    })
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        n = tc['n']
        grid_packed = 0
        for r in range(n):
            for c in range(n):
                val = tc['grid'][r][c]
                grid_packed |= (val << (r * n + c))
        
        cocotb.log.info(f"Running Test: {tc['desc']}")
        
        try:
            # Input Setup
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                # If n is hardcoded in module, we assume it's 8 or handled externally
                pass
                
            if has_signal(dut, 'grid'):
                dut.grid.value = grid_packed
            else:
                # Handle flattened grid ports if array is not supported
                for i in range(n * n):
                    port_name = f'grid_{i}'
                    if has_signal(dut, port_name):
                        r = i // n
                        c = i % n
                        val = (grid_packed >> i) & 1
                        getattr(dut, port_name).value = val
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if clk_present:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                dut.start.value = 0
            
            # Wait for Done
            await wait_for_done(dut)
            
            # Check Result
            imp_val = 0
            if has_signal(dut, 'impossible'):
                imp_val = int(dut.impossible.value)
            
            if tc['expected_imp']:
                if imp_val != 1:
                    cocotb.log.error(f"Expected Impossible=1, got {imp_val}")
                    raise TestFailure("Mismatch on impossibility flag")
                passed += 1
            else:
                if imp_val == 1:
                    raise TestFailure("Expected valid solution, got Impossible")
                
                # Collect outputs
                outputs = []
                out_valid_found = False
                
                # Check out_valid signal first if it exists
                if has_signal(dut, 'out_valid'):
                    out_valid_found = True
                
                # We expect n outputs. The module should output them.
                # Usually, for n=3, we get 3 outputs.
                # We need to read out_row and out_col over cycles.
                
                collected = []
                max_reads = n + 5
                
                for _ in range(max_reads):
                    if clk_present:
                        await RisingEdge(dut.clk)
                    else:
                        await Timer(CLK_NS, units='ns')
                    
                    if has_signal(dut, 'out_valid'):
                        if int(dut.out_valid.value) == 1:
                            row = int(dut.out_row.value)
                            col = int(dut.out_col.value)
                            collected.append((row, col))
                    else:
                        # If no out_valid, assume data is valid continuously
                        row = int(dut.out_row.value)
                        col = int(dut.out_col.value)
                        collected.append((row, col))
                    
                    # Check if we have enough
                    if len(collected) == n:
                        break
                
                if len(collected) != n:
                    raise TestFailure(f"Expected {n} outputs, got {len(collected)}")
                
                # Compare with expected (0-based indices to 1-based conversion logic usually handled by user)
                # The spec says output 1-based integers.
                # My test cases are 0-based. Let's convert expected to 1-based.
                expected_1based = [(r+1, c+1) for r, c in tc['expected_outputs']]
                
                # Sort both lists for comparison because order might vary
                # Actually, order matters for the puzzle? 
                # Usually row-wise or col-wise scan is fixed.
                # Let's sort to be robust to scan order unless order is critical.
                # The problem implies specific output order (row scan usually).
                # Let's assume the module outputs in a deterministic scan order.
                # If the test case expects [(0,0), (1,1), (2,0)], the module might output (0,0), (2,0), (1,1) if scanning columns.
                # The prompt asks for "some way", so order might not be strictly enforced by checker, 
                # but usually competitive programming checkers sort output or require specific order.
                # Here, we will sort both to check existence.
                
                collected_sorted = sorted(collected)
                expected_sorted = sorted(expected_1based)
                
                if collected_sorted != expected_sorted:
                    cocotb.log.error(f"Mismatch. Got {collected_sorted}, Expected {expected_sorted}")
                    raise TestFailure(f"Output mismatch for {tc['desc']}")
                
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test failed: {tc['desc']} - {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
