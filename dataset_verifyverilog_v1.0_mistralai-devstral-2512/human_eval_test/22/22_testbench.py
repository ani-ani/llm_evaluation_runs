import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 8
OUTPUT_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 50

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_result(values, elem_bits=16, max_elems=8):
    packed = 0
    for i, v in enumerate(values[:max_elems]):
        packed |= (v & ((1 << elem_bits) - 1)) << (i * elem_bits)
    return packed

def create_typed_value(val, type_bit):
    """Create 16-bit value: bit 15 is type (0=int, 1=non-int), lower 8 bits = value"""
    return (type_bit << 15) | (val & 0xFF)

def extract_integers(arr):
    """Extract integer values from 16-bit tagged array"""
    integers = []
    for v in arr:
        if (v >> 15) == 0:  # type bit is 0 = integer
            integers.append(v & 0xFF)
    return integers

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, values, width=16):
    for i, v in enumerate(values[:ARRAY_SIZE]):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

def decode_packed_result(packed_val, count, elem_bits=16):
    """Extract integers from packed 256-bit result"""
    result = []
    for i in range(min(count, OUTPUT_SIZE)):
        elem = (packed_val >> (i * elem_bits)) & ((1 << elem_bits) - 1)
        result.append(elem)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_integers(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_arr, expected_integers)
    test_cases = [
        # Empty array
        ([0x8000, 0x8000, 0x8000, 0x8000, 0x8000, 0x8000, 0x8000, 0x8000], [], "All non-integers"),
        # Mixed: integers (type=0) and floats/strings (type=1)
        ([create_typed_value(4, 0), create_typed_value(1, 1), create_typed_value(1, 1), create_typed_value(23, 1), create_typed_value(9, 0), create_typed_value(10, 1), 0x8000, 0x8000], [4, 9], "Mixed types"),
        # Multiple same integers
        ([create_typed_value(3, 0), create_typed_value(1, 1), create_typed_value(3, 0), create_typed_value(3, 0), create_typed_value(1, 1), create_typed_value(1, 1), 0x8000, 0x8000], [3, 3, 3], "Duplicate integers"),
        # All integers
        ([create_typed_value(1, 0), create_typed_value(2, 0), create_typed_value(3, 0), create_typed_value(4, 0), create_typed_value(5, 0), create_typed_value(6, 0), create_typed_value(7, 0), create_typed_value(8, 0)], [1, 2, 3, 4, 5, 6, 7, 8], "All integers")
    ]
    
    passed = failed = 0
    
    for i, (input_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            await write_array(dut, 'arr', input_vals, DATA_WIDTH)
            
            # Start filtering
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read outputs
            if not is_value_defined(dut.count.value):
                raise TestFailure("Count undefined")
            
            count = int(dut.count.value)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_packed = int(dut.result.value)
            result_values = decode_packed_result(result_packed, count)
            
            # Verify count and values
            if count != len(expected):
                raise TestFailure(f"Expected {len(expected)} integers, got {count}")
            
            if result_values != expected:
                raise TestFailure(f"Expected {expected}, got {result_values}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Found {count} integers as expected")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")