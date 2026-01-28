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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Encode 4-char string to 32-bit integer (ASCII)
def encode_string(s):
    if len(s) > 4:
        s = s[:4]
    return sum(ord(c) << (8 * i) for i, c in enumerate(s))

# Decode 32-bit integer to string
def decode_string(encoded):
    s = ""
    for i in range(4):
        char_code = (encoded >> (8 * i)) & 0xFF
        if char_code != 0:
            s += chr(char_code)
    return s

async def write_pairs(dut, pairs):
    # pairs: list of (key_str, value, valid)
    for i, (key_str, value, valid) in enumerate(pairs):
        encoded_key = encode_string(key_str)
        dut.key_in[i].value = encoded_key
        dut.value_in[i].value = value if value >= 0 else (1 << 16) + value  # 16-bit signed
        dut.valid_in[i].value = valid

async def read_output(dut):
    result = []
    for i in range(8):
        if has_signal(dut, f'valid_out_{i}'):
            valid = int(getattr(dut, f'valid_out_{i}').value)
            key = int(getattr(dut, f'key_out_{i}').value)
            value = int(getattr(dut, f'value_out_{i}').value)
        else:
            valid = int(dut.valid_out[i].value)
            key = int(dut.key_out[i].value)
            value = int(dut.value_in[i].value) if has_signal(dut, 'value_in') else int(dut.value_out[i].value)
        
        value_signed = value if value < (1 << 15) else value - (1 << 16)
        key_str = decode_string(key)
        result.append((key_str, value_signed, valid))
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases adapted for fixed-size array
    test_cases = [
        ([('Math', 81, 1), ('Physics', 83, 1), ('Chemistry', 87, 1), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0)],
         [('Chemistry', 87, 1), ('Physics', 83, 1), ('Math', 81, 1)] + [("", 0, 0)] * 5, "Decreasing values"),
        ([('Math', 400, 1), ('Physics', 300, 1), ('Chemistry', 250, 1), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0)],
         [('Math', 400, 1), ('Physics', 300, 1), ('Chemistry', 250, 1)] + [("", 0, 0)] * 5, "Increasing values"),
        ([('Math', 900, 1), ('Physics', 1000, 1), ('Chemistry', 1250, 1), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0), ('Invalid', 0, 0)],
         [('Chemistry', 1250, 1), ('Physics', 1000, 1), ('Math', 900, 1)] + [("", 0, 0)] * 5, "Large values")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (inputs, expected_outputs, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        try:
            await write_pairs(dut, inputs)
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal undefined")
            
            result = await read_output(dut)
            
            # Verify first 3 slots match expected, rest invalid
            for i in range(3):
                key, val, valid = result[i]
                exp_key, exp_val, exp_valid = expected_outputs[i]
                if key != exp_key or val != exp_val or valid != exp_valid:
                    raise TestFailure(f"Slot {i}: Expected ({exp_key}, {exp_val}, {exp_valid}), got ({key}, {val}, {valid})")
            
            for i in range(3, 8):
                key, val, valid = result[i]
                if valid != 0:
                    raise TestFailure(f"Slot {i} should be invalid, got valid={valid}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")