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

def pack_dict_data(keys, vals):
    """Pack 3x8-bit keys and 3x8-bit vals into 16-bit result"""
    # Use key0, val0 for simplicity (8-bit key, 8-bit val)
    packed = (keys[0] & 0xFF) | ((vals[0] & 0xFF) << 8)
    return packed

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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_add_dict_to_tuple(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases based on Python examples
    test_cases = [
        # tuple_in, dict_keys, dict_vals, expected_result
        (
            [4, 5, 6],
            [ord('M'), ord('i'), ord('b')],  # 'M', 'i', 'b' -> 77, 105, 98
            [1, 2, 3],
            [4, 5, 6, 0, 0]  # Last element will be packed dict
        ),
        (
            [1, 2, 3],
            [ord('U'), ord('W'), ord('P')],
            [2, 3, 4],
            [1, 2, 3, 0, 0]
        ),
        (
            [8, 9, 10],
            [ord('P'), ord('A'), ord('O')],
            [3, 4, 5],
            [8, 9, 10, 0, 0]
        )
    ]
    
    passed = 0
    failed = 0
    
    for idx, (tuple_vals, dict_keys, dict_vals, expected_base) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: tuple={tuple_vals}, dict_keys={dict_keys}, dict_vals={dict_vals}")
        
        try:
            # Write inputs
            for i, v in enumerate(tuple_vals):
                dut.tuple_in[i].value = clamp_to_width(v, 16)
            
            for i, v in enumerate(dict_keys):
                dut.dict_keys[i].value = clamp_to_width(v, 8)
            
            for i, v in enumerate(dict_vals):
                dut.dict_vals[i].value = clamp_to_width(v, 8)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check results
            for i in range(4):
                if not is_value_defined(dut.result[i].value):
                    raise TestFailure(f"Result element {i} undefined")
                result_val = int(dut.result[i].value)
                expected = tuple_vals[i]
                if result_val != expected:
                    raise TestFailure(f"Result[{i}]: expected {expected}, got {result_val}")
            
            # Check dict element
            if not is_value_defined(dut.result[4].value):
                raise TestFailure("Result element 4 (dict) undefined")
            
            dict_result = int(dut.result[4].value)
            expected_dict = pack_dict_data(dict_keys, dict_vals)
            if dict_result != expected_dict:
                raise TestFailure(f"Dict result: expected {expected_dict}, got {dict_result}")
            
            cocotb.log.info(f"  PASS: Result = [{tuple_vals[0]}, {tuple_vals[1]}, {tuple_vals[2]}, 0x{dict_result:04X}]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")