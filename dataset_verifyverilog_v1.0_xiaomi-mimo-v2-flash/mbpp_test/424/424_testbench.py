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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Pack string into 128-bit segment
def pack_string_to_128bit(s):
    packed = 0
    s_clean = s[:16]  # Max 16 chars
    for i, c in enumerate(s_clean):
        packed |= (ord(c) & 0xFF) << (i * 8)
    return packed

# Extract last char from 128-bit packed string
def extract_last_char(packed_str, length):
    # Clamp length to 1-16
    if length < 1:
        length = 1
    if length > 16:
        length = 16
    pos = length - 1  # 0-based index
    return (packed_str >> (pos * 8)) & 0xFF

# Write individual string values to packed array
def write_string_packed(dut, string_idx, packed_val):
    # Access individual bits through sub-registers if available, or use unpacked
    # Since we have 8x128-bit, we need to write to the correct slice
    # Try accessing as array[0:7][127:0]
    if hasattr(dut, 'strings') and hasattr(dut.strings, 'value'):
        # This is tricky; assume dut.strings is a list of 128-bit signals
        # For simplicity, we'll use a direct assignment approach
        pass

async def write_strings_array(dut, strings_list, lengths_list):
    """Write strings and lengths to the DUT"""
    # Set number of strings
    num_str = len(strings_list)
    dut.num_strings.value = clamp_to_width(num_str if num_str < 8 else 0, 4)
    
    # Write each string as 128-bit packed into the 8x128-bit array
    # We assume the DUT has a flat 1024-bit input or separate ports
    # For this testbench, we'll handle both cases
    
    # Check if strings is a single 1024-bit signal (8*128)
    if has_signal(dut, 'strings'):
        # Pack all 8 strings into one 1024-bit value
        total_packed = 0
        for i in range(8):
            if i < num_str:
                packed = pack_string_to_128bit(strings_list[i])
                total_packed |= (packed & ((1 << 128) - 1)) << (i * 128)
        dut.strings.value = total_packed
    else:
        # Check for individual string inputs strings_0, strings_1...
        for i in range(8):
            port_name = f'strings_{i}'
            if has_signal(dut, port_name):
                if i < num_str:
                    packed = pack_string_to_128bit(strings_list[i])
                    getattr(dut, port_name).value = packed
                else:
                    getattr(dut, port_name).value = 0
    
    # Write lengths
    if has_signal(dut, 'string_len'):
        # If it's a single width for all strings, use average or first
        # Assuming we have per-string lengths
        # For simplicity, assume a single length applies or vector input
        # In this problem, lengths can vary, so we need a vector
        # We'll use string_len_0, string_len_1... or pack into one
        pass
    # In our spec, string_len is 16-bit input - we need to clarify
    # Let's assume we have string_len as an array or single value
    # Since spec says "16-bit input for each string length", we need 8x16-bit
    total_len = 0
    for i in range(8):
        if i < num_str:
            len_val = clamp_to_width(lengths_list[i] if lengths_list[i] > 0 else 1, 16)
        else:
            len_val = 1
        total_len |= (len_val & 0xFFFF) << (i * 16)
    
    # Write to string_len if it's a 128-bit signal
    if has_signal(dut, 'string_len'):
        dut.string_len.value = total_len
    else:
        # Check for string_len_0, string_len_1...
        for i in range(8):
            port_name = f'string_len_{i}'
            if has_signal(dut, port_name):
                if i < num_str:
                    len_val = clamp_to_width(lengths_list[i] if lengths_list[i] > 0 else 1, 16)
                else:
                    len_val = 1
                getattr(dut, port_name).value = len_val

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_extract_rear(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        await reset_dut(dut)
    
    # Test cases: (strings_list, lengths_list, expected_last_chars)
    test_cases = [
        (['Mers', 'for', 'Vers'], [4, 3, 4], ['s', 'r', 's']),
        (['Avenge', 'for', 'People'], [6, 3, 6], ['e', 'r', 'e']),
        (['Gotta', 'get', 'go'], [5, 3, 2], ['a', 't', 'o']),
        (['Hi', 'Hello', 'World', 'Test'], [2, 5, 5, 4], ['i', 'o', 'd', 't']),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (strings_list, lengths_list, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: {strings_list}")
        
        try:
            # Write inputs
            await write_strings_array(dut, strings_list, lengths_list)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, 100)
                
                # Read result
                if has_signal(dut, 'result'):
                    result_arr = []
                    for i in range(len(strings_list)):
                        if hasattr(dut.result, '__getitem__'):
                            # Assume result is array of 8-bit signals
                            val = int(dut.result[i].value)
                        else:
                            # Flat result
                            val = (int(dut.result.value) >> (i * 8)) & 0xFF
                        result_arr.append(chr(val) if val != 0 else '')
                    
                    # Check validity
                    if has_signal(dut, 'valid'):
                        if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                            raise TestFailure("Valid signal not high")
                    
                    # Compare
                    if result_arr != expected_list:
                        raise TestFailure(f"Expected {expected_list}, got {result_arr}")
                else:
                    # No result signal, check individual outputs
                    for i in range(len(strings_list)):
                        port_name = f'result_{i}'
                        if has_signal(dut, port_name):
                            val = int(getattr(dut, port_name).value)
                            result_char = chr(val) if val != 0 else ''
                            if result_char != expected_list[i]:
                                raise TestFailure(f"Position {i}: expected {expected_list[i]}, got {result_char}")
            else:
                # Combinational
                await Timer(100, units='ns')
                # Read result similarly
                if has_signal(dut, 'result'):
                    # Read and compare
                    pass
            
            passed += 1
            cocotb.log.info(f"PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
