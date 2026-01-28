import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def write_array(dut, name, vals, width):
    # Assuming arr is a sub-interface or array of signals
    for i, v in enumerate(vals):
        # For arr[0], arr[1]... style
        if hasattr(dut, name):
            # Try to access as array
            try:
                getattr(dut, name)[i].value = clamp_to_width(v, width)
            except:
                # Fallback to individual signals if naming convention differs
                getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_big_diff(dut):
    DATA_WIDTH = 8
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        pass
    
    test_cases = [
        ([1,2,3,4], 3, "simple ascending"),
        ([4,5,12], 8, "sample list"),
        ([9,2,3], 7, "unsorted"),
        ([0,0,0,0,0,0,0,0], 0, "all zeros"),
        ([255,254,253,252,251,250,249,248], 7, "large values")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        # Pad input to 8 elements if shorter
        padded = inp + [inp[0] if inp else 0] * (8 - len(inp))
        
        cocotb.log.info(f"Test {i+1}: {desc} Input={padded[:len(inp)]}")
        try:
            # Write array
            await write_array(dut, 'arr', padded, DATA_WIDTH)
            
            # Trigger
            if has_signal(dut, 'start') and has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            if result_val != exp:
                raise TestFailure(f"Expected {exp}, got {result_val}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
