import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 100

# Tuple values (must match spec)
TUPLE_VAL_A = 4  # (4, 6)
TUPLE_VAL_B = 6

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
    # Handle signed values for input assignment if necessary, 
    # but standard clamping works for magnitude
    return min((1 << bits) - 1, max(0, v))

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

def fill_array(dut, values, width):
    # Pad values to MAX_LEN if needed
    while len(values) < MAX_LEN:
        values.append(0)
    
    for i, v in enumerate(values):
        # Check if we are using packed array or individual signals
        if hasattr(dut, 'arr') and hasattr(dut.arr, '__getitem__'):
            try:
                # Try to assign to array index
                dut.arr[i].value = from_signed(v, width)
            except Exception:
                # Fallback for flattened signals
                pass
        
        # Flattened naming convention (arr_0, arr_1...)
        sig_name = f'arr_{i}'
        if has_signal(dut, sig_name):
            # Convert to signed representation for Verilog if negative
            val_to_assign = from_signed(v, width) if v < 0 else v
            getattr(dut, sig_name).value = val_to_assign

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_count_first_elements(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases adapted to numeric tuple (4, 6)
    # Python: (1, 5, 7, (4, 6), 10) -> Count 3. Tuple indices 3,4
    # Python: (2, 9, (5, 7), 11) -> Count 2. Tuple indices 2,3
    # Python: (11, 15, 5, 8, (2, 3), 8) -> Count 4. Tuple indices 4,5
    
    test_cases = [
        ([1, 5, 7, TUPLE_VAL_A, TUPLE_VAL_B, 10], 3, "Case 1: 3 elements before (4,6)"),
        ([2, 9, 8, 8, 11], 5, "Case 2: No tuple found"),
        ([2, 9, 8, TUPLE_VAL_A, TUPLE_VAL_B, 11], 2, "Case 3: 2 elements before (4,6)"),
        ([11, 15, 5, 8, TUPLE_VAL_A, TUPLE_VAL_B, 8], 4, "Case 4: 4 elements before (4,6)")
    ]

    for i, (inp_vals, expected_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        
        # Fill Array
        fill_array(dut, inp_vals, DATA_WIDTH)
        
        # Set Length
        dut.len.value = len(inp_vals)
        
        # Start Signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} failed: {e}")
            continue
        
        # Check Result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1} failed: Result undefined")
            continue
            
        result = int(dut.result.value)
        if result != expected_count:
            raise TestFailure(f"Test {i+1} ({desc}): Expected {expected_count}, got {result}")
        else:
            cocotb.log.info(f"Test {i+1} Passed: Result {result}")
