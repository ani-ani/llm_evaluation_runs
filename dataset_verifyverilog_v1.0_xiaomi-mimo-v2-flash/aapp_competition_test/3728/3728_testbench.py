import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 400  # 20x20
CLK_NS = 10
MAX_CYCLES = 50000  # Allow enough time for worst-case iteration

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def pack_table(table, n, m):
    packed = 0
    for r in range(n):
        for c in range(m):
            idx = r * 20 + c
            val = table[r][c]
            packed |= (val & 0xFF) << (idx * 8)
    return packed

async def write_table(dut, table, n, m):
    # If table is unpacked array:
    if has_signal(dut, 'table_data'):
        # Check if it's a 2D array or flat
        try:
            # Try accessing table_data as 2D array
            for r in range(n):
                for c in range(m):
                    dut.table_data[r][c].value = clamp_to_width(table[r][c], 8)
        except (AttributeError, TypeError):
            # Assume flat array
            packed = pack_table(table, n, m)
            dut.table_data.value = packed
    else:
        # Check for individual signals arr_0_0, arr_0_1...
        for r in range(n):
            for c in range(m):
                sig_name = f'table_data_{r}_{c}'
                if has_signal(dut, sig_name):
                    getattr(dut, sig_name).value = clamp_to_width(table[r][c], 8)
                else:
                    # Flat signal naming
                    flat_idx = r * 20 + c
                    sig_name = f'table_data_{flat_idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(table[r][c], 8)

def generate_test_case(n, m, answer):
    # Generates a random test case with given answer
    import random
    base = list(range(1, m + 1))
    table = []
    
    if answer == 'YES':
        # Make it solvable
        # Pick a column swap (or none)
        col_swap = random.choice([None] + [(c1, c2) for c1 in range(m) for c2 in range(c1, m)])
        
        for _ in range(n):
            row = base[:]
            # Apply row swaps (at most one)
            if random.random() < 0.7:
                i1, i2 = random.sample(range(m), 2)
                row[i1], row[i2] = row[i2], row[i1]
            table.append(row)
            
        # Apply column swap if any
        if col_swap:
            c1, c2 = col_swap
            for r in range(n):
                table[r][c1], table[r][c2] = table[r][c2], table[r][c1]
    else:
        # Make it unsolvable (e.g., too many mismatches)
        for _ in range(n):
            row = base[:]
            # Randomly permute
            random.shuffle(row)
            table.append(row)
            # Ensure >2 mismatches for at least one row if we don't swap columns
            # But we might swap columns. Hard to guarantee 'NO' without search.
            # For simplicity, we'll just use a known NO case from the problem
            pass
    
    return table

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_basic(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Example 1 (YES)
    n1, m1 = 2, 4
    table1 = [
        [1, 3, 2, 4],
        [1, 3, 4, 2]
    ]
    
    # Test Case 2: Example 2 (NO)
    n2, m2 = 4, 4
    table2 = [
        [1, 2, 3, 4],
        [2, 3, 4, 1],
        [3, 4, 1, 2],
        [4, 1, 2, 3]
    ]
    
    test_cases = [
        (n1, m1, table1, 1, "Example 1 YES"),
        (n2, m2, table2, 0, "Example 2 NO")
    ]
    
    for i, (n, m, table, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        await write_table(dut, table, n, m)
        
        if is_seq:
            # Set n and m if inputs exist
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'm'):
                dut.m.value = m
                
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            result_val = int(dut.result.value)
            if result_val != expected:
                raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result_val}")
            else:
                cocotb.log.info(f"Test {i+1} Passed: Got {result_val}")
        else:
            # Combinational check (if logic allows)
            await Timer(100, units='ns')
            if is_value_defined(dut.result):
                result_val = int(dut.result.value)
                if result_val != expected:
                    raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result_val}")

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_edge_cases(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Edge case: n=1, m=1 (Identity)
    n, m = 1, 1
    table = [[1]]
    expected = 1  # YES
    
    await write_table(dut, table, n, m)
    if is_seq:
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'm'):
            dut.m.value = m
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result_val = int(dut.result.value)
        if result_val != expected:
            raise TestFailure(f"Edge case Failed: Expected {expected}, got {result_val}")

@cocotb.test(timeout_time=200, timeout_unit='ms')
async def test_large_n(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Large n case from problem inputs (simplified for speed)
    # Input: 20 2
    n, m = 20, 2
    table = [
        [1, 2],
        [1, 2],
        [1, 2],
        [2, 1],
        [1, 2],
        [1, 2],
        [2, 1],
        [1, 2],
        [2, 1],
        [2, 1],
        [2, 1],
        [1, 2],
        [2, 1],
        [2, 1],
        [1, 2],
        [1, 2],
        [2, 1],
        [2, 1],
        [1, 2],
        [2, 1]
    ]
    expected = 1  # YES (swap columns 0 and 1 makes all [2,1] -> [1,2])
    
    await write_table(dut, table, n, m)
    if is_seq:
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'm'):
            dut.m.value = m
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result_val = int(dut.result.value)
        if result_val != expected:
            raise TestFailure(f"Large N Failed: Expected {expected}, got {result_val}")
        else:
            cocotb.log.info(f"Large N Passed: Got {result_val}")
