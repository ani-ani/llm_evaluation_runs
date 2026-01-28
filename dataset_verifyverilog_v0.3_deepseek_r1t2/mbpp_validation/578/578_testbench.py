import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# Helper Functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_arrays(dut, arr1, arr2, arr3):
    """Write three arrays to the DUT. Handles both indexed ports and 2D arrays."""
    length = len(arr1)
    for i in range(length):
        # Try arr1_0, arr1_1 style first
        if has_signal(dut, f'arr1_{i}'):
            getattr(dut, f'arr1_{i}').value = clamp_to_width(arr1[i], DATA_WIDTH)
            getattr(dut, f'arr2_{i}').value = clamp_to_width(arr2[i], DATA_WIDTH)
            getattr(dut, f'arr3_{i}').value = clamp_to_width(arr3[i], DATA_WIDTH)
        else:
            # Fallback to 2D array syntax
            dut.arr1[i].value = clamp_to_width(arr1[i], DATA_WIDTH)
            dut.arr2[i].value = clamp_to_width(arr2[i], DATA_WIDTH)
            dut.arr3[i].value = clamp_to_width(arr3[i], DATA_WIDTH)

async def read_stream_and_verify(dut, expected):
    """Read interleaved stream and verify against expected list."""
    results = []
    timeout = 0
    
    # Wait for valid or done
    while timeout < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            if is_value_defined(dut.result.value):
                results.append(int(dut.result.value))
            else:
                raise TestFailure("Result undefined when valid is high")
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        timeout += 1
    
    if timeout >= MAX_CYCLES:
        raise TestFailure(f"Timeout reading stream. Got {len(results)} values")
    
    if len(results) != len(expected):
        raise TestFailure(f"Length mismatch: expected {len(expected)}, got {len(results)}")
    
    for i, (actual, exp) in enumerate(zip(results, expected)):
        if actual != exp:
            raise TestFailure(f"Mismatch at {i}: expected {exp}, got {actual}")
    
    return results

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_basic_interleave(dut):
    """Test basic interleaving functionality."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1,2,3,4,5,6,7], [10,20,30,40,50,60,70], [100,200,300,400,500,600,700],
         [1,10,100,2,20,200,3,30,300,4,40,400,5,50,500,6,60,600,7,70,700]),
        ([10,20], [15,2], [5,10], [10,15,5,20,2,10]),
        ([11,44], [10,15], [20,5], [11,10,20,44,15,5])
    ]
    
    for i, (a1, a2, a3, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: len={len(a1)}")
        
        await write_arrays(dut, a1, a2, a3)
        if has_signal(dut, 'len'):
            dut.len.value = len(a1)
        
        await RisingEdge(dut.clk)
        await start_computation(dut)
        
        results = await read_stream_and_verify(dut, exp)
        cocotb.log.info(f"  PASS: {results}")

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: single element, max length, boundary values."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Single element
    cocotb.log.info("Edge Test 1: Single element")
    await write_arrays(dut, [255], [128], [1])
    if has_signal(dut, 'len'):
        dut.len.value = 1
    await RisingEdge(dut.clk)
    await start_computation(dut)
    results = await read_stream_and_verify(dut, [255, 128, 1])
    cocotb.log.info(f"  PASS: {results}")
    
    # Test 2: Maximum length
    cocotb.log.info("Edge Test 2: Maximum length (8)")
    a1 = [1, 2, 3, 4, 5, 6, 7, 8]
    a2 = [10, 20, 30, 40, 50, 60, 70, 80]
    a3 = [100, 200, 300, 400, 500, 600, 700, 800]
    exp = []
    for j in range(8):
        exp.extend([a1[j], a2[j], a3[j]])
    
    await write_arrays(dut, a1, a2, a3)
    if has_signal(dut, 'len'):
        dut.len.value = 8
    await RisingEdge(dut.clk)
    await start_computation(dut)
    results = await read_stream_and_verify(dut, exp)
    cocotb.log.info(f"  PASS: Generated {len(results)} values")
    
    # Test 3: Boundary values
    cocotb.log.info("Edge Test 3: Boundary values (0, 255)")
    await write_arrays(dut, [0, 255], [255, 0], [0, 255])
    if has_signal(dut, 'len'):
        dut.len.value = 2
    await RisingEdge(dut.clk)
    await start_computation(dut)
    results = await read_stream_and_verify(dut, [0, 255, 0, 255, 0, 255])
    cocotb.log.info(f"  PASS: {results}")
