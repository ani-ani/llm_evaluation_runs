import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i >= ARRAY_SIZE: break
        attr = getattr(dut, name)
        if hasattr(attr, '__getitem__'):
            attr[i].value = clamp_to_width(v, width)
        else:
            # Handle individual signals arr_0, arr_1...
            port = getattr(dut, f"{name}_{i}")
            port.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_solution(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([5, 8, 7, 1], 12, "Odd at even: [5,8,7,1] -> pos0=5, pos2=7"),
        ([3, 3, 3, 3, 3], 9, "All odd: [3,3,3,3,3] -> pos0+pos2+pos4=9"),
        ([30, 13, 24, 321], 0, "Even pos not odd: [30,13,24,321] -> pos0=30, pos2=24"),
        ([5, 9], 5, "Two elements: [5,9] -> pos0=5"),
        ([2, 4, 8], 0, "All even: [2,4,8] -> no odd"),
        ([30, 13, 23, 32], 23, "Mixed: [30,13,23,32] -> pos2=23"),
        ([3, 13, 2, 9], 3, "Two odd even pos: [3,13,2,9] -> pos0=3"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array
            await write_array(dut, 'arr', inp, DATA_WIDTH)
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = len(inp)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
