import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers (Mandatory)
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

async def write_array(dut, name, vals, width, max_len=16):
    # Set array elements individually
    for i, v in enumerate(vals[:max_len]):
        getattr(dut, name)[i].value = clamp_to_width(v, width)
    # Zero out remaining elements if needed (for known inputs)
    for i in range(len(vals), max_len):
        getattr(dut, name)[i].value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_intersperse(dut):
    DATA_WIDTH = 8
    MAX_INPUT_LEN = 16
    MAX_OUTPUT_LEN = 32
    CLK_NS = 10
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: assume outputs settle quickly
        await Timer(1, units='ns')
    
    test_cases = [
        ([], 7, [], 0),
        ([5,6,3,2], 8, [5,8,6,8,3,8,2], 7),
        ([2,2,2], 2, [2,2,2,2,2], 5),
        ([1], 10, [1], 1),
    ]
    
    passed = failed = 0
    
    for i, (inp, delim, exp_out, exp_len) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={inp}, Delim={delim}")
        try:
            # Write inputs
            await write_array(dut, 'arr_in', inp, DATA_WIDTH, MAX_INPUT_LEN)
            dut.delim.value = clamp_to_width(delim, DATA_WIDTH)
            dut.len_in.value = len(inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.len_out.value):
                raise TestFailure("len_out undefined")
            
            result_len = int(dut.len_out.value)
            if result_len != exp_len:
                raise TestFailure(f"Expected len={exp_len}, got {result_len}")
            
            # Read array elements
            result_arr = []
            for j in range(exp_len):
                elem = getattr(dut, f'arr_out[{j}]').value if has_signal(dut, f'arr_out[{j}]') else getattr(dut, 'arr_out')[j].value
                if not is_value_defined(elem):
                    raise TestFailure(f"arr_out[{j}] undefined")
                result_arr.append(int(elem))
            
            if result_arr != exp_out:
                raise TestFailure(f"Expected {exp_out}, got {result_arr}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")