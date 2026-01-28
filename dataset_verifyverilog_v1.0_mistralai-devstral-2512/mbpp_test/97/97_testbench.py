import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 4, 16, 10, 1000

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

async def wait_for_done(dut, max_cycles=200):
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

async def write_lists(dut, lists):
    """Write 4x4 2D array to module inputs"""
    for i in range(4):
        for j in range(4):
            elem = lists[i][j]
            # Try to access as lists_0_0, lists_0_1, etc.
            sig_name = f'lists_{i}_{j}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(elem, DATA_WIDTH)
            else:
                # Try as lists[i][j] array access
                try:
                    dut.lists[i][j].value = clamp_to_width(elem, DATA_WIDTH)
                except Exception:
                    raise TestFailure(f"Cannot write lists[{i}][{j}]")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frequency_lists(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([[1, 2, 3, 2], [4, 5, 6, 2], [7, 8, 9, 5], [0,0,0,0]], 
         {1:1,2:3,3:1,4:1,5:2,6:1,7:1,8:1,9:1}, "test1"),
        ([[1,2,3,4],[5,6,7,8],[9,10,11,12],[0,0,0,0]],
         {1:1,2:1,3:1,4:1,5:1,6:1,7:1,8:1,9:1,10:1,11:1,12:1}, "test2"),
        ([[20,30,40,17],[18,16,14,13],[10,20,30,40],[0,0,0,0]],
         {20:2,30:2,40:2,17:1,18:1,16:1,14:1,13:1,10:1}, "test3")
    ]
    
    passed = failed = 0
    for i, (inp, expected_dict, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_lists(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=150)
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not has_signal(dut, 'result_count'):
                raise TestFailure("Missing result_count signal")
            
            result_count = int(dut.result_count.value)
            
            # Build result dictionary
            actual_dict = {}
            for j in range(result_count):
                val_sig = getattr(dut, f'result_val_{j}') if has_signal(dut, f'result_val_{j}') else dut.result_val[j]
                cnt_sig = getattr(dut, f'result_cnt_{j}') if has_signal(dut, f'result_cnt_{j}') else dut.result_cnt[j]
                
                val = int(val_sig.value)
                cnt = int(cnt_sig.value)
                actual_dict[val] = cnt
            
            # Compare
            if actual_dict != expected_dict:
                raise TestFailure(f"Expected {expected_dict}, got {actual_dict}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
