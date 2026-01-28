import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_assembly(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test case 1: Sample Input
    symbols = ['a', 'b']
    # Table: row i (sym i), col j (sym j): time-result
    # 0: a, 1: b
    # a-a: 3-b -> time=3, result=b(1)
    # a-b: 5-b -> time=5, result=b(1)
    # b-a: 6-a -> time=6, result=a(0)
    # b-b: 2-b -> time=2, result=b(1)
    table = [
        [(3, 1), (5, 1)],  # a-*
        [(6, 0), (2, 1)]   # b-*
    ]
    
    # Pack table into 23-bit values (20-bit time, 3-bit result)
    table_packed = []
    for row in table:
        row_packed = []
        for time, res in row:
            packed = (time << 3) | res
            row_packed.append(packed)
        table_packed.append(row_packed)
    
    # Test strings
    test_cases = [
        {"string": "aba", "expected_time": 9, "expected_type": 1},  # 9-b
        {"string": "bba", "expected_time": 8, "expected_type": 0},  # 8-a
    ]
    
    # Map char to index
    sym_map = {c: i for i, c in enumerate(symbols)}
    
    for tc in test_cases:
        # Prepare string indices
        str_indices = [sym_map[c] for c in tc["string"]]
        string_len = len(str_indices)
        
        # Set inputs
        dut.sym_count.value = len(symbols)
        dut.string_len.value = string_len
        
        # Write string chars
        for i in range(8):
            if i < len(str_indices):
                getattr(dut, f'string_chars[{i}]').value = str_indices[i]
            else:
                getattr(dut, f'string_chars[{i}]').value = 0
        
        # Write assembly table
        for r in range(8):
            for c in range(8):
                val = table_packed[r][c] if r < len(table_packed) and c < len(table_packed[0]) else 0
                if has_signal(dut, f'assembly_table[{r}][{c}]'):
                    getattr(dut, f'assembly_table[{r}][{c}]').value = val
                else:
                    # Try packed array syntax
                    pass
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.result_time.value):
            raise TestFailure("Result time undefined")
        if not is_value_defined(dut.result_type.value):
            raise TestFailure("Result type undefined")
        
        result_time = int(dut.result_time.value)
        result_type = int(dut.result_type.value)
        
        # Check
        if result_time != tc["expected_time"]:
            raise TestFailure(f"Time mismatch for '{tc['string']}': expected {tc['expected_time']}, got {result_time}")
        if result_type != tc["expected_type"]:
            raise TestFailure(f"Type mismatch for '{tc['string']}': expected {tc['expected_type']}, got {result_type}")
        
        cocotb.log.info(f"PASS: '{tc['string']}' -> {result_time}-{symbols[result_type]}")
    
    # Test case 2: Second sample
    # Symbols: m(0), e(1)
    # Table:
    # m-m: 5-e (5,1)
    # m-e: 4-m (4,0)
    # e-m: 3-e (3,1)
    # e-e: 4-m (4,0)
    symbols2 = ['m', 'e']
    table2 = [
        [(5, 1), (4, 0)],
        [(3, 1), (4, 0)]
    ]
    
    table_packed2 = []
    for row in table2:
        row_packed = []
        for time, res in row:
            packed = (time << 3) | res
            row_packed.append(packed)
        table_packed2.append(row_packed)
    
    test_cases2 = [
        {"string": "eme", "expected_time": 7, "expected_type": 0},  # 7-m
    ]
    
    sym_map2 = {c: i for i, c in enumerate(symbols2)}
    
    for tc in test_cases2:
        str_indices = [sym_map2[c] for c in tc["string"]]
        string_len = len(str_indices)
        
        dut.sym_count.value = len(symbols2)
        dut.string_len.value = string_len
        
        for i in range(8):
            if i < len(str_indices):
                getattr(dut, f'string_chars[{i}]').value = str_indices[i]
            else:
                getattr(dut, f'string_chars[{i}]').value = 0
        
        for r in range(8):
            for c in range(8):
                val = table_packed2[r][c] if r < len(table_packed2) and c < len(table_packed2[0]) else 0
                if has_signal(dut, f'assembly_table[{r}][{c}]'):
                    getattr(dut, f'assembly_table[{r}][{c}]').value = val
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result_time = int(dut.result_time.value)
        result_type = int(dut.result_type.value)
        
        if result_time != tc["expected_time"]:
            raise TestFailure(f"Time mismatch for '{tc['string']}': expected {tc['expected_time']}, got {result_time}")
        if result_type != tc["expected_type"]:
            raise TestFailure(f"Type mismatch for '{tc['string']}': expected {tc['expected_type']}, got {result_type}")
        
        cocotb.log.info(f"PASS: '{tc['string']}' -> {result_time}-{symbols2[result_type]}")
    
    cocotb.log.info("All tests passed!")