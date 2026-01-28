import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def ascii_to_int(s):
    return [ord(c) for c in s]

def int_to_ascii(i):
    return chr(i) if 32 <= i <= 126 else '.'

# Array write helper
def write_2d_array(dut, prefix, data, rows, cols):
    """Write 2D array data to flattened ports"""
    flat = []
    for r in range(rows):
        row = data[r] if r < len(data) else [46]*cols  # '.' default
        for c in range(cols):
            flat.append(clamp_to_width(row[c], 8))
    
    # Write to dut.prefix_r_c ports
    for r in range(16):
        for c in range(16):
            port_name = f"{prefix}_{r}_{c}"
            if has_signal(dut, port_name):
                idx = r * 16 + c
                val = flat[idx] if idx < len(flat) else 46
                getattr(dut, port_name).value = val

def read_2d_array(dut, prefix, rows, cols):
    """Read solved grid from 2D array ports"""
    result = []
    for r in range(rows):
        row = []
        for c in range(cols):
            port_name = f"{prefix}_{r}_{c}"
            if has_signal(dut, port_name):
                val = int(getattr(dut, port_name).value)
                row.append(val)
        result.append(row)
    return result

def write_word_list(dut, words, max_words=32, max_len=16):
    """Write list of words to padded 2D storage"""
    for i in range(max_words):
        word = words[i] if i < len(words) else ""
        padded = (word + "\0" * max_len)[:max_len]  # Pad with null
        ascii_vals = ascii_to_int(padded)
        for j in range(max_len):
            port_name = f"words_{i}_{j}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = ascii_vals[j]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_crossword_solver(dut):
    """Test crossword solver with multiple test cases"""
    
    CLK_NS = 10
    MAX_CYCLES = 1000000  # 2^20 ~ 1M cycles
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Case 1: 1x15 grid, 1 word
        {
            "grid": [[35,35,46,46,46,46,46,46,46,46,46,35,35,35,35]],  # ##.........####
            "rows": 1, "cols": 15,
            "words": ["CROSSWORD"],
            "expected": [[35,35,67,82,79,83,83,87,79,82,68,35,35,35,35]]  # ##CROSSWORD####
        },
        # Case 2: 3x6 grid, 6 words
        {
            "grid": [
                [35,46,46,46,46,46],  # #.....
                [46,46,46,46,35,35],  # ....##
                [35,35,35,46,46,46]   # ###...
            ],
            "rows": 3, "cols": 6,
            "words": ["AT", "ME", "DOG", "GOD", "VETO", "MAGIC"],
            "expected": [
                [35,77,65,71,73,67],  # #MAGIC
                [86,69,84,79,35,35],  # VETO##
                [35,35,35,68,79,71]   # ###DOG
            ]
        }
    ]
    
    passed = 0
    failed = 0
    
    for t_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test Case {t_idx+1} ===")
        
        try:
            # Write inputs
            write_2d_array(dut, "grid", tc["grid"], tc["rows"], tc["cols"])
            write_word_list(dut, tc["words"])
            
            # Set control signals
            if is_seq:
                if has_signal(dut, 'grid_rows'):
                    getattr(dut, 'grid_rows').value = tc["rows"]
                if has_signal(dut, 'grid_cols'):
                    getattr(dut, 'grid_cols').value = tc["cols"]
                if has_signal(dut, 'num_words'):
                    getattr(dut, 'num_words').value = len(tc["words"])
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Check valid and read result
                if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                    raise TestFailure("Result not valid")
                
                # Read result grid
                result = read_2d_array(dut, "result_grid", tc["rows"], tc["cols"])
                
                # Compare
                exp_flat = [val for row in tc["expected"] for val in row]
                res_flat = [val for row in result for val in row]
                
                if exp_flat != res_flat:
                    raise TestFailure(f"Mismatch\nExpected: {tc['expected']}\nGot: {result}")
                
            else:
                # Combinational - immediate check
                await Timer(100, units='ns')
                if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                    raise TestFailure("Result not valid")
                
                result = read_2d_array(dut, "result_grid", tc["rows"], tc["cols"])
                exp_flat = [val for row in tc["expected"] for val in row]
                res_flat = [val for row in result for val in row]
                
                if exp_flat != res_flat:
                    raise TestFailure(f"Mismatch\nExpected: {tc['expected']}\nGot: {result}")
            
            cocotb.log.info(f"Test {t_idx+1}: PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {t_idx+1}: FAILED - {e}")
            failed += 1
            
        # Reset for next test
        if is_seq and t_idx < len(test_cases) - 1:
            await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\n=== Summary: {passed}/{len(test_cases)} tests passed ===")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)