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

def pack_string(s, max_len=8):
    """Pack ASCII string into integer, zero-padded"""
    packed = 0
    for i, c in enumerate(s[:max_len]):
        packed |= (ord(c) << (i * 8))
    return packed

def unpack_string(val, max_len=8):
    """Unpack integer to ASCII string"""
    chars = []
    for i in range(max_len):
        char_val = (val >> (i * 8)) & 0xFF
        if char_val != 0:
            chars.append(chr(char_val))
    return ''.join(chars)

def create_input_str(quoted_strings):
    """Create packed input string with quotes and separators"""
    # Build string: "str1","str2","str3"...
    parts = []
    for s in quoted_strings:
        parts.append('\"' + s + '\"')
    full_str = ','.join(parts)
    return pack_string(full_str, 16)

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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_extract_quotes(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_strings, expected_count, description)
    test_cases = [
        (['Python', 'PHP', 'Java'], 3, "3 quoted strings"),
        (['python', 'program', 'language'], 3, "3 compact strings"),
        (['red', 'blue', 'green', 'yellow'], 4, "4 quoted strings"),
        ([], 0, "empty input"),
        (['test'], 1, "single string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (strings, exp_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Create input
            input_packed = create_input_str(strings)
            dut.input_str.value = input_packed
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=50)
            
            # Check result_count
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("result_count undefined")
            
            actual_count = int(dut.result_count.value)
            if actual_count != exp_count:
                raise TestFailure(f"Expected count {exp_count}, got {actual_count}")
            
            # Check results
            results = []
            for j in range(4):
                result_name = f'result_{j}'
                if has_signal(dut, result_name):
                    val = int(getattr(dut, result_name).value)
                    results.append(unpack_string(val))
                else:
                    results.append('')
            
            # Verify extracted strings
            for idx, expected in enumerate(strings):
                if idx >= actual_count:
                    break
                if results[idx] != expected:
                    raise TestFailure(f"String {idx}: expected '{expected}', got '{results[idx]}'")
            
            # Verify extra results are empty
            for idx in range(actual_count, 4):
                if results[idx] != '':
                    raise TestFailure(f"Extra result {idx} should be empty, got '{results[idx]}'")
            
            passed += 1
            cocotb.log.info(f"  PASS: count={actual_count}, strings={results[:actual_count]}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")