import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def calculate_expected(arr):
    """Calculate expected sum: even values at odd indices"""
    total = 0
    for i, val in enumerate(arr):
        if (i % 2 == 1) and (val % 2 == 0):
            total += val
    return total

def write_array_to_dut(dut, values):
    """Write array values to individual ports"""
    for i in range(min(ARRAY_SIZE, len(values))):
        port_name = f'arr_{i}'
        if hasattr(dut, port_name):
            val = clamp_to_width(values[i], DATA_WIDTH)
            getattr(dut, port_name).value = val

def get_array_from_dut(dut):
    """Read array values from individual ports"""
    arr = []
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if hasattr(dut, port_name):
            arr.append(int(getattr(dut, port_name).value))
        else:
            arr.append(0)
    return arr

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_even_at_odd_indices(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_result, description)
    test_cases = [
        ([4, 88], 88, "Simple case: index1 even"),
        ([4, 5, 6, 7, 2, 122], 122, "Multiple elements: only index5 (122)"),
        ([4, 0, 6, 7], 0, "Zero at odd index"),
        ([4, 4, 6, 8], 12, "Two even numbers at odd indices: 4+8=12"),
        ([2, 3, 4, 5, 6, 7, 8, 9], 4+6+8, "Full 8 elements"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 2+4+6+8, "Mixed odds/evens"),
        ([10, 11, 12, 13], 12, "Even numbers only at odd indices"),
        ([100, 200, 300, 400], 200+400, "Large values"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 0, "All odd - should be 0"),
        ([2, 2, 2, 2, 2, 2, 2, 2], 2+2+2+2, "All even"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, "All zeros"),
        ([255, 254, 253, 252], 254, "Max 8-bit values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pad or truncate input to ARRAY_SIZE
            padded_input = inp + [0] * (ARRAY_SIZE - len(inp))
            
            # Write array to DUT
            write_array_to_dut(dut, padded_input)
            
            if is_seq:
                # Start calculation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational - wait for output to stabilize
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} for input {padded_input}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result} == {exp}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")
