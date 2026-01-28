import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

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

def char_to_ascii(c):
    return ord(c) if isinstance(c, str) and len(c) == 1 else 0

def ascii_to_char(v):
    return chr(v) if 32 <= v <= 126 else '?'

async def write_dict(dut, prefix, dict_data, length):
    """Write a dictionary to input array ports"""
    keys = [char_to_ascii(k) for k in dict_data.keys()]
    vals = [char_to_ascii(v) for v in dict_data.values()]
    
    for i in range(8):
        if i < length and i < len(keys):
            getattr(dut, f'{prefix}_key')[i].value = clamp_to_width(keys[i], 8)
            getattr(dut, f'{prefix}_val')[i].value = clamp_to_width(vals[i], 8)
        else:
            getattr(dut, f'{prefix}_key')[i].value = 0
            getattr(dut, f'{prefix}_val')[i].value = 0
    
    getattr(dut, f'{prefix}_len').value = clamp_to_width(length, 4)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_merge_dictionaries(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Basic merge with overlaps
    test1_dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    test1_dict2 = {"G": "Green", "W": "White"}
    test1_dict3 = {"O": "Orange", "W": "White", "B": "Black"}
    expected1 = {'B': 'Black', 'R': 'Red', 'P': 'Pink', 'G': 'Green', 'W': 'White', 'O': 'Orange'}
    
    # Test case 2: Overwrite dict1 with dict2
    test2_dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    test2_dict2 = {"G": "Green", "W": "White"}
    test2_dict3 = {"L": "lavender", "B": "Blue"}
    expected2 = {'W': 'White', 'P': 'Pink', 'B': 'Black', 'R': 'Red', 'G': 'Green', 'L': 'lavender'}
    
    # Test case 3: Different insertion order
    test3_dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    test3_dict2 = {"L": "lavender", "B": "Blue"}
    test3_dict3 = {"G": "Green", "W": "White"}
    expected3 = {'B': 'Black', 'P': 'Pink', 'R': 'Red', 'G': 'Green', 'L': 'lavender', 'W': 'White'}
    
    test_cases = [
        (test1_dict1, test1_dict2, test1_dict3, expected1, "Test 1: Overlap dict3"),
        (test2_dict1, test2_dict2, test2_dict3, expected2, "Test 2: Overwrite dict1"),
        (test3_dict1, test3_dict2, test3_dict3, expected3, "Test 3: Different order"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (dict1, dict2, dict3, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        try:
            # Write all input dictionaries
            await write_dict(dut, 'key1', dict1, len(dict1))
            await write_dict(dut, 'val1', dict1, len(dict1))
            await write_dict(dut, 'key2', dict2, len(dict2))
            await write_dict(dut, 'val2', dict2, len(dict2))
            await write_dict(dut, 'key3', dict3, len(dict3))
            await write_dict(dut, 'val3', dict3, len(dict3))
            
            # Trigger merge
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            # Verify outputs
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal undefined")
            
            if int(dut.done.value) != 1:
                raise TestFailure("Done signal not set")
            
            if not is_value_defined(dut.out_len.value):
                raise TestFailure("Output length undefined")
            
            out_len = int(dut.out_len.value)
            
            # Collect output dictionary
            out_dict = {}
            for i in range(out_len):
                if i < ARRAY_SIZE:
                    key_val = int(dut.out_key[i].value) if is_value_defined(dut.out_key[i].value) else 0
                    val_val = int(dut.out_val[i].value) if is_value_defined(dut.out_val[i].value) else 0
                    out_dict[ascii_to_char(key_val)] = ascii_to_char(val_val)
            
            # Compare with expected
            if len(out_dict) != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {len(out_dict)}")
            
            for k, v in expected.items():
                if k not in out_dict:
                    raise TestFailure(f"Key '{k}' missing from output")
                if out_dict[k] != v:
                    raise TestFailure(f"Key '{k}': expected '{v}', got '{out_dict[k]}'")
            
            cocotb.log.info(f"  PASS: {out_len} entries correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")