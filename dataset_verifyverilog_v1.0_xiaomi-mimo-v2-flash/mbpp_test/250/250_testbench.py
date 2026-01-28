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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 8
MAX_ARRAY_LEN = 12
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_x(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (array, target, expected_result, description)
    test_cases = [
        ((10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2), 4, 0, "element not in array"),
        ((10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2), 10, 3, "count of 10"),
        ((10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2), 8, 4, "count of 8"),
        ((1, 2, 3, 4, 5), 1, 1, "single occurrence"),
        ((1, 2, 3, 4, 5), 5, 1, "last element"),
        ((5, 5, 5, 5), 5, 4, "all elements same"),
        ((1, 1, 1, 1, 1), 2, 0, "no match"),
        ((), 5, 0, "empty array"),  # len=0
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_tuple, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array to dut
            arr_len = len(arr_tuple)
            
            # Check if dut has array elements arr_0, arr_1...
            has_individual_arr = has_signal(dut, 'arr_0')
            if has_individual_arr:
                # Set arr_0 to arr_11
                for idx in range(12):
                    port_name = f'arr_{idx}'
                    if has_signal(dut, port_name):
                        val = clamp_to_width(arr_tuple[idx] if idx < arr_len else 0, DATA_WIDTH)
                        getattr(dut, port_name).value = val
            elif has_signal(dut, 'arr'):
                # Set array element by element
                for idx in range(12):
                    if idx < len(dut.arr):
                        val = clamp_to_width(arr_tuple[idx] if idx < arr_len else 0, DATA_WIDTH)
                        dut.arr[idx].value = val
            else:
                raise TestFailure("Neither arr[N] nor arr vector found")
            
            # Set target
            if has_signal(dut, 'target'):
                dut.target.value = clamp_to_width(target, DATA_WIDTH)
            else:
                raise TestFailure("target signal not found")
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(arr_len, 4)
            else:
                raise TestFailure("len signal not found")
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, 50)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
            # Wait for next cycle
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            await reset_dut(dut)
    
    cocotb.log.info(f"\nTest Results: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
