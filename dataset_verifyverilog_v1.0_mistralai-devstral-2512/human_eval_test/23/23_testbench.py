import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test function

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_strlen(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([0]*16, 0, "Empty string"),
        ([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1, "Single char 'x'"),
        ([97, 115, 100, 97, 115, 110, 97, 107, 106, 0, 0, 0, 0, 0, 0, 0], 9, "'asdasnakj'"),
        ([1]*16, 16, "Full non-null string"),
        ([0]*15 + [1], 15, "Null terminator at index 15"),
        ([10, 20, 30, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, "Four chars")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array (16 individual 8-bit inputs)
            for idx, val in enumerate(inp):
                port_name = f'string_data_{idx}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Port {port_name} not found")
            
            # Start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.length.value):
                raise TestFailure("Result 'length' undefined")
            
            result = int(dut.length.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            # Check done signal pulse width (should be 1 cycle)
            # Done is already high at this rising edge (triggered by wait_for_done)
            # Check next cycle
            await RisingEdge(dut.clk)
            if int(dut.done.value) != 0:
                raise TestFailure(f"'done' signal stayed high for more than 1 cycle")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")