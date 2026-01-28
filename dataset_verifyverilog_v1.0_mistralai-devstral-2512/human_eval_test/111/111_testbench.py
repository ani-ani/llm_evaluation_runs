import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Convert string to ASCII list
def str_to_ascii(s):
    return [ord(c) for c in s]

# Extract individual letter/count from packed arrays
def extract_packed_array(dut, name, elem_bits, count):
    values = []
    packed = getattr(dut, name).value
    for i in range(count):
        shift = i * elem_bits
        mask = (1 << elem_bits) - 1
        val = (packed >> shift) & mask
        values.append(val)
    return values

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'char_done'): dut.char_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_string(dut, s):
    """Feed string character by character, respecting ready signal"""
    ascii_list = str_to_ascii(s)
    for i, ascii_val in enumerate(ascii_list):
        # Wait for ready
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
                break
        else:
            raise TestFailure("ready never asserted")
        
        # Send character
        dut.char_in.value = ascii_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
    
    # Send char_done
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
            break
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_histogram(dut):
    # Setup
    has_clk = has_signal(dut, 'clk')
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ('a b b a', {'a': 2, 'b': 2}),
        ('a b c a b', {'a': 2, 'b': 2}),
        ('a b c d g', {'a': 1, 'b': 1, 'c': 1, 'd': 1, 'g': 1}),
        ('r t g', {'r': 1, 't': 1, 'g': 1}),
        ('b b b b a', {'b': 4}),
        ('', {}),
        ('a', {'a': 1}),
    ]
    
    passed = failed = 0
    
    for i, (inp_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp_str}' -> {expected}")
        
        try:
            if has_clk:
                await feed_string(dut, inp_str)
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Extract results
            if not has_signal(dut, 'result_letters') or not has_signal(dut, 'result_counts'):
                raise TestFailure("Missing result signals")
            
            result_letters = extract_packed_array(dut, 'result_letters', 8, 16)
            result_counts = extract_packed_array(dut, 'result_counts', 4, 16)
            result_len = int(dut.result_len.value) if is_value_defined(dut.result_len.value) else 0
            
            # Build result dictionary
            result_dict = {}
            for i in range(result_len):
                if result_letters[i] == 0:
                    continue
                letter = chr(result_letters[i])
                result_dict[letter] = result_counts[i]
            
            # Verify
            if result_dict != expected:
                raise TestFailure(f"Expected {expected}, got {result_dict}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_dict}")
            
            # Reset for next test
            if has_clk and i < len(test_cases) - 1:
                await reset_dut(dut)
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")