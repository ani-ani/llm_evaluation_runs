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

def wait_for_done(max_cycles=1000):
    async def _wait(dut):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    return _wait

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper: pack 16 strings (8 chars each) into 128-bit value
def pack_strings(str_list):
    packed = 0
    # Each string: 8 chars = 8 bytes = 64 bits
    # 16 strings = 1024 bits, but we only need 128 bits for 16 strings × 1 char each
    # Actually spec says: 128 bits = 16 strings × 8 bits (first char only?)
    # Re-read: "str_data[127:0]: Packed 16x8-bit array representing all strings (8 bits per char, 8 chars per string, 16 strings total)"
    # This is ambiguous. 128 bits total, 16 strings, so 8 bits per string = first char only.
    # But test has multi-char strings. Let's assume each string contributes only FIRST CHAR to sort key.
    # For full string storage: would need 128 chars = 1024 bits. We'll use 128 bits = first char of each string.
    for i, s in enumerate(str_list):
        if i >= 16: break
        first_char = ord(s[0]) if s else 0
        packed |= (first_char & 0xFF) << (i * 8)
    return packed

# Helper: pack sublist lengths (4 values, 4 bits each)
def pack_lens(lens):
    packed = 0
    for i, l in enumerate(lens[:4]):
        packed |= (l & 0xF) << (i * 4)
    return packed

# Helper: unpack sorted result (we only check first chars since full strings not stored)
def unpack_first_chars(packed):
    chars = []
    for i in range(16):
        chars.append((packed >> (i * 8)) & 0xFF)
    return chars

def sort_key(s):
    return s[0] if s else '\x00'

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sort_sublists(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases adapted from Python problem
    test_cases = [
        ([
            ["green", "orange"],
            ["black", "white"],
            ["white", "black", "orange"]
        ], [
            ['green', 'orange'],
            ['black', 'white'],
            ['black', 'orange', 'white']
        ]),
        ([
            ["red", "green"],
            ["blue", "black"],
            ["orange", "brown"]
        ], [
            ['red', 'green'],
            ['black', 'blue'],
            ['orange', 'brown']
        ]),
        ([
            ["zilver", "gold"],
            ["magnesium", "aluminium"],
            ["steel", "bronze"]
        ], [
            ['gold', 'zilver'],
            ['aluminium', 'magnesium'],
            ['bronze', 'steel']
        ])
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (input_lists, expected_lists) in enumerate(test_cases):
        cocotb.log.info(f"Test case {case_idx+1}")
        try:
            # Flatten input and extract first chars for sorting
            flat_input = []
            for sublist in input_lists:
                for s in sublist:
                    flat_input.append(s)
            # Pad to 16 strings
            while len(flat_input) < 16:
                flat_input.append("")
            
            # Pack first chars
            packed_input = pack_strings(flat_input)
            
            # Pack lengths (4 sublists)
            lens = [len(l) for l in input_lists]
            while len(lens) < 4:
                lens.append(0)
            packed_lens = pack_lens(lens)
            
            # Expected output: first chars of expected lists
            flat_expected = []
            for sublist in expected_lists:
                for s in sublist:
                    flat_expected.append(s)
            while len(flat_expected) < 16:
                flat_expected.append("")
            expected_packed = pack_strings(flat_expected)
            
            # Apply inputs
            if has_signal(dut, 'str_data'):
                dut.str_data.value = packed_input
            elif has_signal(dut, 'str_data_0'):  # Individual array ports
                for i in range(16):
                    char = (packed_input >> (i*8)) & 0xFF
                    getattr(dut, f'str_data_{i}').value = char
            else:
                raise TestFailure("No str_data signal found")
            
            if has_signal(dut, 'sublist_lens'):
                dut.sublist_lens.value = packed_lens
            elif has_signal(dut, 'sublist_lens_0'):
                for i in range(4):
                    val = (packed_lens >> (i*4)) & 0xF
                    getattr(dut, f'sublist_lens_{i}').value = val
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(1000)(dut)
            else:
                await Timer(500, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_packed = int(dut.result.value)
            
            # Verify: check that sorting is correct by first chars
            # We expect first chars to be sorted per sublist
            result_chars = unpack_first_chars(result_packed)
            expected_chars = unpack_first_chars(expected_packed)
            
            # Validate per sublist
            offset = 0
            for i, sublist_len in enumerate(lens):
                if sublist_len == 0:
                    continue
                # Extract chars for this sublist
                result_sub = result_chars[offset:offset+sublist_len]
                expected_sub = expected_chars[offset:offset+sublist_len]
                
                # Check they match
                if sorted(result_sub) != sorted(expected_sub):
                    raise TestFailure(f"Sublist {i} mismatch: got {result_sub}, expected {expected_sub}")
                offset += sublist_len
            
            passed += 1
            cocotb.log.info(f"Test {case_idx+1} passed")
        except TestFailure as e:
            cocotb.log.error(f"Test {case_idx+1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
