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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

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

async def write_array(dut, values):
    # Write to individual array elements
    for i in range(ARRAY_SIZE):
        val = values[i] if i < len(values) else 0
        # Clamp to unsigned 8-bit range
        clamped = clamp_to_width(val, DATA_WIDTH)
        getattr(dut, f'arr_{i}').value = clamped

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_element(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_max, description)
    test_cases = [
        ([1, 2, 3, 0, 0, 0, 0, 0], 3, "simple ascending"),
        ([5, 3, 2, 2, 3, 9, 0, 0], 9, "mixed values"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, "all zeros"),
        ([255, 200, 150, 100, 50, 0, 1, 2], 255, "max value 255"),
        ([10, 10, 10, 10, 10, 10, 10, 10], 10, "all same"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            await write_array(dut, inp)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")