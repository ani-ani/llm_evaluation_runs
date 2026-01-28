import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000
ROTATION_BITS = 4

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v = int(v)
    if v < 0:
        return 0
    elif v > max_val:
        return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_array(dut, values):
    """Write values to individual input ports arr_in_0 through arr_in_15"""
    for i in range(ARRAY_SIZE):
        port_name = f'arr_in_{i}'
        if has_signal(dut, port_name):
            val = clamp_to_width(values[i], DATA_WIDTH)
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Signal {port_name} not found")

async def read_output_array(dut):
    """Read values from individual output ports arr_out_0 through arr_out_15"""
    result = []
    for i in range(ARRAY_SIZE):
        port_name = f'arr_out_{i}'
        if has_signal(dut, port_name):
            val = int(getattr(dut, port_name).value)
            result.append(val)
        else:
            raise TestFailure(f"Signal {port_name} not found")
    return result

def right_rotate_list(arr, n):
    """Python reference implementation for right rotation"""
    if not arr:
        return []
    n = n % len(arr)
    if n == 0:
        return arr[:]
    return arr[-n:] + arr[:-n]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rotate_array(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test cases: (input_array, rotation_count, expected_output, description)
    test_cases = [
        (
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
            3,
            [14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
            "Rotate 16-element array by 3"
        ),
        (
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
            2,
            [15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            "Rotate 16-element array by 2"
        ),
        (
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
            5,
            [12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            "Rotate 16-element array by 5"
        ),
        (
            [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160],
            0,
            [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160],
            "Rotate by 0 (no change)"
        ),
        (
            [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240],
            8,
            [247, 246, 245, 244, 243, 242, 241, 240, 255, 254, 253, 252, 251, 250, 249, 248],
            "Rotate with max values"
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_arr, rot_count, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        cocotb.log.info(f"  Input: {input_arr}")
        cocotb.log.info(f"  Rotation: {rot_count}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write input array
            await write_input_array(dut, input_arr)
            
            # Set rotation count
            dut.rotation_count.value = clamp_to_width(rot_count, ROTATION_BITS)
            
            # Assert start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Check busy signal
            if has_signal(dut, 'busy'):
                await RisingEdge(dut.clk)
                if not int(dut.busy.value):
                    cocotb.log.warning("Busy signal not asserted after start")
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=100)
            
            # Read output array
            result = await read_output_array(dut)
            cocotb.log.info(f"  Got: {result}")
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
            # Wait for next test
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset for next test
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Final check
    if failed > 0:
        raise TestFailure(f"\n{failed} tests failed out of {passed + failed} total tests")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")