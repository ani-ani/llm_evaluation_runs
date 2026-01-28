import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
STRING_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

def encode_string(s):
    """Convert ASCII string to 8-byte array (8-bit chars)"""
    encoded = [0] * STRING_WIDTH
    for i, c in enumerate(s[:STRING_WIDTH]):
        encoded[i] = ord(c)
    return encoded

def pack_bytes(values, bits=8):
    """Pack array of bytes into single integer"""
    result = 0
    for i, v in enumerate(values[:STRING_WIDTH]):
        result |= (v & ((1 << bits) - 1)) << (i * bits)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def write_dict(dut, dictionary):
    """Write dictionary entries to input arrays"""
    entries = list(dictionary.items())
    
    # Clear valid_in first
    for i in range(ARRAY_SIZE):
        dut.valid_in[i].value = 0
    
    for i, (key, value) in enumerate(entries):
        if i >= ARRAY_SIZE:
            break
        # Write key as ASCII bytes
        encoded_key = encode_string(key)
        for j in range(STRING_WIDTH):
            dut.key_in[i][j].value = clamp_to_width(encoded_key[j], DATA_WIDTH)
        # Write value
        dut.value_in[i].value = clamp_to_width(value, DATA_WIDTH)
        # Set valid
        dut.valid_in[i].value = 1

async def read_result(dut):
    """Read filtered result from output arrays"""
    result = {}
    count = safe_int(dut.count.value)
    
    if count == 0:
        return result
    
    for i in range(ARRAY_SIZE):
        if safe_int(dut.valid_out[i].value) == 1:
            # Decode key from bytes
            key_bytes = []
            for j in range(STRING_WIDTH):
                key_bytes.append(safe_int(dut.key_out[i][j].value))
            # Convert bytes to string
            key_str = ''.join(chr(b) if b > 0 else '' for b in key_bytes).strip()
            if key_str:  # Only add if non-empty
                value = safe_int(dut.value_out[i].value)
                result[key_str] = value
    
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dict_filter(dut):
    """Test dictionary filter module"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 
         170, 
         {'Cierra Vega': 175, 'Alden Cantrell': 180, 'Pierre Cox': 190},
         "Test 1: Filter >= 170"),
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 
         180, 
         {'Alden Cantrell': 180, 'Pierre Cox': 190},
         "Test 2: Filter >= 180"),
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 
         190, 
         {'Pierre Cox': 190},
         "Test 3: Filter >= 190"),
        ({'Test': 100, 'Case': 200}, 150, {'Case': 200}, "Test 4: Simple case"),
        ({'Empty': 50}, 60, {}, "Test 5: No matches"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_dict, threshold, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input data
            await write_dict(dut, input_dict)
            dut.threshold.value = clamp_to_width(threshold, DATA_WIDTH)
            
            if is_seq:
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            # Read result
            result = await read_result(dut)
            
            # Compare
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Verify count
            expected_count = len(expected)
            actual_count = safe_int(dut.count.value)
            if actual_count != expected_count:
                raise TestFailure(f"Expected count {expected_count}, got {actual_count}")
            
            passed += 1
            cocotb.log.info(f"  PASSED: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"\nAll tests passed: {passed}/{len(test_cases)}")