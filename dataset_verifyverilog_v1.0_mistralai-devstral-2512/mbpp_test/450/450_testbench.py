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

# Helper to set string in 2D array
# dut.arr[i] is a LogicArray for the 8-byte string
async def set_string(dut, index, s):
    # Ensure string is max 8 chars
    s = s[:8]
    # Convert to ASCII integers
    data = [ord(c) for c in s]
    # Pad with zeros if needed
    while len(data) < 8:
        data.append(0)
    
    # Access the array element (LogicArray)
    # We need to assign the whole 8-byte chunk at once if possible, or bit slice
    # Since dut.str_arr[index] is likely a LogicArray of 64 bits
    val = 0
    for i, byte in enumerate(data):
        val |= (byte & 0xFF) << (i * 8)
    dut.str_arr[index].value = val

# Helper to read result
async def get_string(dut, index):
    val = int(dut.result_arr[index].value)
    s = ""
    for i in range(8):
        byte = (val >> (i * 8)) & 0xFF
        if byte == 0:
            break
        s += chr(byte)
    return s

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_extract_string(dut):
    # Check for mandatory signals
    if not all([has_signal(dut, 'clk'), has_signal(dut, 'rst_n'), has_signal(dut, 'start'), has_signal(dut, 'done')]):
        raise TestFailure("Mandatory signals (clk, rst_n, start, done) missing")

    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len_req.value = 0
    for i in range(16):
        dut.str_arr[i].value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Cases
    test_data = [
        {
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'length': 8,
            'expected': ['practice', 'solution']
        },
        {
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'length': 6,
            'expected': ['Python']
        },
        {
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'length': 9,
            'expected': ['exercises']
        }
    ]

    for test_idx, case in enumerate(test_data):
        cocotb.log.info(f"--- Running Test {test_idx + 1} ---")
        
        # Prepare input array
        # Initialize all 16 slots to 0
        for i in range(16):
            dut.str_arr[i].value = 0
            dut.result_arr[i].value = 0
        
        # Set input strings
        for i, s in enumerate(case['strings']):
            await set_string(dut, i, s)
            
        # Set target length
        dut.len_req.value = case['length']

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        done_found = False
        for _ in range(30): # Wait up to 30 cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {test_idx+1}: Done signal not asserted within timeout")

        # Verify results
        found_count = int(dut.result_count.value)
        expected_count = len(case['expected'])
        
        if found_count != expected_count:
            raise TestFailure(f"Test {test_idx+1}: Count mismatch. Expected {expected_count}, got {found_count}")

        extracted_strings = []
        for i in range(16):
            s = await get_string(dut, i)
            if s: # Only collect non-empty strings
                extracted_strings.append(s)
        
        # Compare extracted strings (order matters as per spec)
        if extracted_strings != case['expected']:
            raise TestFailure(f"Test {test_idx+1}: Result mismatch. Expected {case['expected']}, got {extracted_strings}")
        
        cocotb.log.info(f"Test {test_idx+1} Passed")
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
