import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
INTERNAL_WIDTH = 16  # For multiplication results
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 50

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

def to_twos_complement(val, bits):
    if val < 0:
        return (1 << bits) + val
    return val

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python Reference Implementation
def max_subarray_product_ref(arr):
    n = len(arr)
    max_ending_here = 1
    min_ending_here = 1
    max_so_far = 0
    flag = 0
    for i in range(0, n):
        if arr[i] > 0:
            max_ending_here = max_ending_here * arr[i]
            min_ending_here = min(min_ending_here * arr[i], 1)
            flag = 1
        elif arr[i] == 0:
            max_ending_here = 1
            min_ending_here = 1
        else:
            temp = max_ending_here
            max_ending_here = max(min_ending_here * arr[i], 1)
            min_ending_here = temp * arr[i]
        if (max_so_far < max_ending_here):
            max_so_far = max_ending_here
    if flag == 0 and max_so_far == 0:
        return 0
    return max_so_far

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_product_subarray(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test Cases
    # Case 1: [1, -2, -3, 0, 7, -8, -2] -> 112
    # Case 2: [6, -3, -10, 0, 2] -> 180
    # Case 3: [-2, -40, 0, -2, -3] -> 80
    test_cases = [
        ([1, -2, -3, 0, 7, -8, -2], 112, "Mixed with zero"),
        ([6, -3, -10, 0, 2], 180, "Large neg product"),
        ([-2, -40, 0, -2, -3], 80, "Pos product of negs"),
        ([5], 5, "Single positive"),
        ([-5], -5, "Single negative"),
        ([0, 0, 0], 0, "All zeros"),
        ([2, 3, -2, 4], 48, "Classic")
    ]

    passed = 0
    failed = 0

    for i, (inp_list, expected, desc) in enumerate(test_cases):
        # Prepare input list to exactly ARRAY_SIZE
        inp_padded = inp_list + [0] * (ARRAY_SIZE - len(inp_list))
        
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp_list}")
        
        try:
            # Drive inputs (arr_0 to arr_7)
            for idx, val in enumerate(inp_padded):
                # Clamp and convert to unsigned for HDL port if needed, or just assign int
                # For signed 8-bit ports, we use from_signed logic if the port is expecting signed interpretation
                # Usually Verilog ports are plain logic, Python int handles signed correctly via Z handling in simulator or explicit conversion
                # We assign the 2's complement representation for 8 bits
                port_name = f'arr_{idx}'
                if has_signal(dut, port_name):
                    val_2comp = to_twos_complement(val, DATA_WIDTH)
                    getattr(dut, port_name).value = val_2comp
                elif has_signal(dut, 'arr') and hasattr(dut.arr, '__getitem__'):
                     val_2comp = to_twos_complement(val, DATA_WIDTH)
                     dut.arr[idx].value = val_2comp
                else:
                     # Try packed input if exists
                     pass
            
            if has_signal(dut, 'len'):
                # Set len based on actual input length (not padded)
                dut.len.value = len(inp_list)
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, 20)
            else:
                # Combinational logic or simple pipeline
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X or Z)")
            
            # Interpret result as 16-bit signed
            res_raw = int(dut.result.value)
            result = to_signed(res_raw, 16)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed}/{len(test_cases)} tests failed")