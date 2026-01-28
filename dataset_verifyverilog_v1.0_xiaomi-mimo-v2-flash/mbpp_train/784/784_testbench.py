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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def reset_values():
    return (0xFF, 0xFF, 0)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < 8:  # Max 8 elements
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def compute_expected(first_even, first_odd):
    return first_even * first_odd

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_mul_even_odd(dut):
    # Clock setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')
    
    # Test cases: (input_list, expected_product, description)
    # Note: len input is clamped to 8 for hardware constraint
    test_cases = [
        ([1,3,5,7,4,1,6,8], 4, "mix: even=4, odd=1"),
        ([1,2,3,4,5,6,7,8], 2, "even=2, odd=1"),
        ([1,5,7,9,10], 10, "even=10, odd=1"),
        ([2,4,6,8], 0x1FE, "all even: even=2, odd=-1"),
        ([1,3,5,7], 0xFF, "all odd: even=-1, odd=1"),
        ([1,1,1,2], 2, "delayed even: even=2, odd=1"),
        ([2,2,2,1], 2, "delayed odd: even=2, odd=1"),
        ([0,1,2,3], 0, "zero even: even=0, odd=1")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_list, expected_product, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp to max 8 elements
            actual_len = min(len(inp_list), 8)
            arr = inp_list[:8]
            
            # Write array
            await write_array(dut, 'arr', arr, 8)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = actual_len
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=30)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected_product:
                raise TestFailure(f"Expected {expected_product} (0x{expected_product:04X}), got {result} (0x{result:04X})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
