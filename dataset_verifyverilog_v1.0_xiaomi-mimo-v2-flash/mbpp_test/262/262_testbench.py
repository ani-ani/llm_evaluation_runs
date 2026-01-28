import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

async def read_array(dut, name, width):
    vals = []
    for i in range(ARRAY_SIZE):
        val = getattr(dut, name)[i].value
        if is_value_defined(val):
            vals.append(int(val) & ((1 << width) - 1))
    return vals

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_split_two_parts(dut):
    # Clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # (in_data, in_len, L, exp_first, exp_second, desc)
        ([1,1,2,3,4,4,5,1], 8, 3, [1,1,2], [3,4,4,5,1], "numbers split"),
        ([0x61,0x62,0x63,0x64], 4, 2, [0x61,0x62], [0x63,0x64], "ASCII split"),
        ([0x70,0x79,0x74,0x68,0x6F,0x6E], 6, 4, [0x70,0x79,0x74,0x68], [0x6F,0x6E], "python split"),
        ([5,6,7], 3, 5, [5,6,7], [], "L > in_len"),
        ([1,2,3,4], 4, 0, [], [1,2,3,4], "L = 0")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, in_len, L, exp_first, exp_second, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input data
            await write_array(dut, 'in_data', inp, DATA_WIDTH)
            
            # Write parameters
            dut.in_len.value = clamp_to_width(in_len, 4)
            dut.L.value = clamp_to_width(L, 4)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            first_len = int(dut.first_len.value)
            second_len = int(dut.second_len.value)
            
            # Read output arrays
            out_first = await read_array(dut, 'out_first', DATA_WIDTH)
            out_second = await read_array(dut, 'out_second', DATA_WIDTH)
            
            # Extract actual values (only first len elements matter)
            actual_first = out_first[:first_len]
            actual_second = out_second[:second_len]
            
            # Compare
            if actual_first != exp_first:
                raise TestFailure(f"First part mismatch: expected {exp_first}, got {actual_first}")
            if actual_second != exp_second:
                raise TestFailure(f"Second part mismatch: expected {exp_second}, got {actual_second}")
            if first_len != len(exp_first):
                raise TestFailure(f"First length mismatch: expected {len(exp_first)}, got {first_len}")
            if second_len != len(exp_second):
                raise TestFailure(f"Second length mismatch: expected {len(exp_second)}, got {second_len}")
            
            cocotb.log.info(f"  Result: first={actual_first}, second={actual_second}")
            cocotb.log.info(f"  Lengths: first={first_len}, second={second_len}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed}")