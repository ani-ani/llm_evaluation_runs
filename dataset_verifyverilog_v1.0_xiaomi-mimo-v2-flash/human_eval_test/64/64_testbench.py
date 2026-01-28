import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Mandatory Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if is_value_defined(dut.clk):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')
    dut.rst_n.value = 1
    if is_value_defined(dut.clk):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        if is_value_defined(dut.clk):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done signal not asserted within {max_cycles} cycles")

# --- String Helper ---
def str_to_ascii_array(s, max_len=16):
    """Converts Python string to list of ASCII integer values."""
    if len(s) > max_len:
        raise ValueError(f"String length {len(s)} exceeds max {max_len}")
    return [ord(c) for c in s] + [0] * (max_len - len(s))

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_vowels_count(dut):
    # Configuration
    CLK_NS = 10
    ARRAY_SIZE = 16
    DATA_WIDTH = 8
    
    # Setup Clock if present
    if has_signal(dut, 'clk'):
        is_seq = True
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        is_seq = False
        dut.rst_n.value = 1

    # Test Cases: (Input String, Expected Count, Description)
    test_cases = [
        ("abcde", 2, "Simple lower case"),
        ("Alone", 3, "Mixed case"),
        ("key", 2, "'y' at end"),
        ("bye", 1, "'y' not at end"),
        ("keY", 2, "'Y' at end uppercase"),
        ("bYe", 1, "'Y' not at end uppercase"),
        ("ACEDY", 3, "Test 7"),
        ("", 0, "Empty string"),
        ("bcdfg", 0, "No vowels"),
        ("aaaaa", 5, "All vowels"),
        ("yyy", 3, "All 'y' at end"),
        ("yyyy", 4, "Four 'y' at end"),
        ("yabc", 1, "'y' at start only"),
        ("test", 1, "One vowel 'e'"),
        ("crypt", 1, "'y' at end"),
    ]

    passed = 0
    failed = 0

    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{test_str}' (Expected: {expected}) - {desc}")
        
        try:
            # Prepare input data
            ascii_vals = str_to_ascii_array(test_str, ARRAY_SIZE)
            str_len = len(test_str)
            
            # Assign to DUT
            # 1. Handle str_data (array of signals)
            if has_signal(dut, 'str_data'):
                # Check if it's an array (list) or packed
                if isinstance(getattr(dut, 'str_data'), list) or hasattr(getattr(dut, 'str_data'), '__len__'):
                    for j in range(ARRAY_SIZE):
                        if j < len(ascii_vals):
                            dut.str_data[j].value = clamp_to_width(ascii_vals[j], DATA_WIDTH)
                        else:
                            dut.str_data[j].value = 0
                else:
                    # Packed array logic (unlikely for 16x8, but good practice)
                    packed_val = 0
                    for j in range(ARRAY_SIZE):
                        packed_val |= (clamp_to_width(ascii_vals[j], DATA_WIDTH) << (j*8))
                    dut.str_data.value = packed_val
            else:
                # Individual ports str_data_0, str_data_1...
                for j in range(ARRAY_SIZE):
                    port_name = f'str_data_{j}'
                    if has_signal(dut, port_name):
                        val = ascii_vals[j] if j < len(ascii_vals) else 0
                        getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # 2. Handle str_len
            if has_signal(dut, 'str_len'):
                dut.str_len.value = clamp_to_width(str_len, 4)
            else:
                # Check for len alias
                if has_signal(dut, 'len'):
                    dut.len.value = clamp_to_width(str_len, 4)

            # 3. Start Sequence
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined (X/Z)")
                
                result_val = int(dut.result.value)
                if result_val != expected:
                    raise TestFailure(f"Mismatch: Expected {expected}, got {result_val}")
            else:
                # Combinational (instant result)
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined (X/Z)")
                result_val = int(dut.result.value)
                if result_val != expected:
                    raise TestFailure(f"Mismatch: Expected {expected}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed.")
