import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

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

# Helper to write strings into dut signals
async def write_strings(dut, strings):
    MAX_STRINGS = 8
    for i in range(MAX_STRINGS):
        if i < len(strings):
            s = strings[i]
            # Pad to 8 chars with nulls
            padded = (s + '\x00' * 8)[:8]
            for j, char in enumerate(padded):
                # Each char is 8-bit ASCII
                addr = (i << 3) | j  # Index into strings
                getattr(dut, f'strings_{addr}').value = ord(char)
        else:
            # Empty string (all nulls)
            for j in range(8):
                addr = (i << 3) | j
                getattr(dut, f'strings_{addr}').value = 0
    
    if has_signal(dut, 'num_strings'):
        dut.num_strings.value = len(strings)

async def read_result(dut):
    if not has_signal(dut, 'result'):
        raise TestFailure("Missing 'result' signal")
    result = []
    for i in range(64):
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
            if is_value_defined(val):
                v = int(val)
                if v != 0:
                    result.append(chr(v))
                else:
                    break
        else:
            raise TestFailure(f"Missing 'result_{i}' signal")
    return ''.join(result)

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_concatenate(dut):
    # Check signals
    required_inputs = ['strings_0', 'strings_1', 'strings_2', 'strings_3', 'strings_4', 'strings_5', 'strings_6', 'strings_7', 'num_strings']
    required_outputs = ['result_0', 'result_1', 'result_2', 'result_3', 'result_4', 'result_5', 'result_6', 'result_7', 'result_8']
    
    for sig in required_inputs:
        if not has_signal(dut, sig):
            cocotb.log.warning(f"Missing required input signal: {sig}")
    
    for sig in required_outputs:
        if not has_signal(dut, sig):
            cocotb.log.warning(f"Missing required output signal: {sig}")
    
    test_cases = [
        ([], ''),
        (['x', 'y', 'z'], 'xyz'),
        (['x', 'y', 'z', 'w', 'k'], 'xyzwk'),
        (['hello', ' ', 'world'], 'hello world'),
        (['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], 'abcdefgh'),
        (['123', '456'], '123456'),
    ]
    
    passed = 0
    failed = 0
    
    for inp, exp in test_cases:
        cocotb.log.info(f"Testing: {inp}")
        try:
            await write_strings(dut, inp)
            await Timer(100, units='ns')  # Propagation delay
            
            result = await read_result(dut)
            if result != exp:
                raise TestFailure(f"Expected '{exp}', got '{result}'")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"Unexpected error: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")