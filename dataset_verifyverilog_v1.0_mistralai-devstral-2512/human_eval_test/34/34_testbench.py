import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_unique_sort(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_list, expected_output_list, description)
    test_cases = [
        ([5, 3, 5, 2, 3, 3, 9, 0], [0, 2, 3, 5, 9], "basic unique sort"),
        ([1, 1, 1, 1, 1, 1, 1, 1], [1], "all duplicates"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0], "all zeros"),
        ([255, 1, 128, 64, 32, 16, 8, 4], [4, 8, 16, 32, 64, 128, 255, 1], "large values"),
        ([10, 20, 30, 40, 50, 60, 70, 80], [10, 20, 30, 40, 50, 60, 70, 80], "already sorted"),
        ([8, 7, 6, 5, 4, 3, 2, 1], [1, 2, 3, 4, 5, 6, 7, 8], "reverse sorted"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            for idx in range(MAX_LEN):
                arr_val = inp[idx] if idx < len(inp) else 0
                dut.arr[idx].value = clamp_to_width(arr_val, DATA_WIDTH)
            
            if is_seq:
                dut.len.value = len(inp)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            result_list = []
            out_len = 0
            if is_seq:
                out_len = int(dut.out_len.value)
                for idx in range(out_len):
                    val = int(dut.result[idx].value)
                    result_list.append(val)
            
            # Compare
            if result_list != exp:
                raise TestFailure(f"Expected {exp}, got {result_list} (len={out_len})")
            
            passed += 1
            cocotb.log.info(f"PASS: {result_list}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")