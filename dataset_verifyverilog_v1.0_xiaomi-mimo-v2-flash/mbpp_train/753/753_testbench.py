import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

# Constants
DATA_WIDTH = 8
NAME_WIDTH = 64
NUM_RECORDS = 8
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers

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
    return min((1 << bits) - 1, max(0, int(v)))

def string_to_name(s):
    """Convert 8-char string to 64-bit packed value"""
    s = s.ljust(8, ' ')[:8]
    result = 0
    for i, ch in enumerate(s):
        result |= ord(ch) << (i * 8)
    return result

def name_to_string(val):
    """Convert 64-bit packed value back to string"""
    chars = []
    for i in range(8):
        char_val = (val >> (i * 8)) & 0xFF
        if char_val == 0x20:  # space
            chars.append(' ')
        else:
            chars.append(chr(char_val))
    return ''.join(chars).rstrip(' ')

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test data
TEST_CASES = [
    {  # Test 1
        'name': "Test 1: K=2, basic",
        'K': 2,
        'records': [
            ('Manjeet', 10),
            ('Akshat', 4),
            ('Akash', 2),
            ('Nikhil', 8)
        ],
        'expected': [
            ('Akash', 2),
            ('Akshat', 4)
        ]
    },
    {  # Test 2
        'name': "Test 2: K=3",
        'K': 3,
        'records': [
            ('Sanjeev', 11),
            ('Angat', 5),
            ('Akash', 3),
            ('Nepin', 9)
        ],
        'expected': [
            ('Akash', 3),
            ('Angat', 5),
            ('Nepin', 9)
        ]
    },
    {  # Test 3
        'name': "Test 3: K=1",
        'K': 1,
        'records': [
            ('tanmay', 14),
            ('Amer', 11),
            ('Ayesha', 9),
            ('SKD', 16)
        ],
        'expected': [
            ('Ayesha', 9)
        ]
    }
]

async def write_input(dut, K, records, valid_mask=None):
    """Write K and input records to DUT"""
    dut.K.value = clamp_to_width(K, 4)
    
    # Write up to NUM_RECORDS
    for i in range(NUM_RECORDS):
        if i < len(records):
            name, val = records[i]
            dut.names_in[i].value = string_to_name(name)
            dut.values_in[i].value = clamp_to_width(val, DATA_WIDTH)
            if valid_mask:
                dut.valid_in[i].value = valid_mask[i]
            else:
                dut.valid_in[i].value = 1
        else:
            dut.names_in[i].value = 0
            dut.values_in[i].value = 0
            dut.valid_in[i].value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_k_records(dut):
    """Test minimum K records function"""
    
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for test_case in TEST_CASES:
        cocotb.log.info(f"Running {test_case['name']}")
        
        try:
            # Write inputs
            await write_input(dut, test_case['K'], test_case['records'])
            
            # Start operation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.valid_count.value):
                raise TestFailure("valid_count is undefined")
            
            valid_count = int(dut.valid_count.value)
            expected_count = min(test_case['K'], len(test_case['records']))
            
            if valid_count != expected_count:
                raise TestFailure(f"Expected valid_count={expected_count}, got {valid_count}")
            
            # Read and verify each output record
            for i in range(expected_count):
                exp_name, exp_val = test_case['expected'][i]
                
                if not is_value_defined(dut.names_out[i].value):
                    raise TestFailure(f"names_out[{i}] is undefined")
                if not is_value_defined(dut.values_out[i].value):
                    raise TestFailure(f"values_out[{i}] is undefined")
                
                out_name_val = int(dut.names_out[i].value)
                out_val = int(dut.values_out[i].value)
                
                out_name_str = name_to_string(out_name_val)
                
                if out_name_str != exp_name or out_val != exp_val:
                    raise TestFailure(
                        f"Output mismatch at index {i}: "
                        f"Expected ('{exp_name}', {exp_val}), "
                        f"Got ('{out_name_str}', {out_val})"
                    )
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")