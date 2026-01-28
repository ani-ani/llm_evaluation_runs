import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 8
KEY_WIDTH = 64
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# HELPER FUNCTIONS

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_string(s, max_len=8):
    s_padded = s.ljust(max_len, ' ')[:max_len]
    result = 0
    for i, char in enumerate(s_padded):
        result |= ord(char) << ((max_len - 1 - i) * 8)
    return result

def pack_dict_to_arrays(test_dict):
    keys = list(test_dict.keys())
    values = list(test_dict.values())
    while len(keys) < 4:
        keys.append("")
        values.append(0)
    key_packed = [pack_string(k) for k in keys[:4]]
    return key_packed, values[:4]

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# MAIN TEST

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dict_filter(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 170, {'Cierra Vega': 175, 'Alden Cantrell': 180, 'Pierre Cox': 190}, "Filter threshold 170"),
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 180, {'Alden Cantrell': 180, 'Pierre Cox': 190}, "Filter threshold 180"),
        ({'Cierra Vega': 175, 'Alden Cantrell': 180, 'Kierra Gentry': 165, 'Pierre Cox': 190}, 190, {'Pierre Cox': 190}, "Filter threshold 190"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (test_dict, threshold, expected_dict, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        try:
            key_vals, val_vals = pack_dict_to_arrays(test_dict)
            
            dut.key_0.value = key_vals[0]
            dut.key_1.value = key_vals[1]
            dut.key_2.value = key_vals[2]
            dut.key_3.value = key_vals[3]
            
            dut.val_0.value = clamp_to_width(val_vals[0], DATA_WIDTH)
            dut.val_1.value = clamp_to_width(val_vals[1], DATA_WIDTH)
            dut.val_2.value = clamp_to_width(val_vals[2], DATA_WIDTH)
            dut.val_3.value = clamp_to_width(val_vals[3], DATA_WIDTH)
            
            dut.threshold.value = clamp_to_width(threshold, DATA_WIDTH)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                raise TestFailure("Done signal not asserted")
            
            out_count = int(dut.out_count.value)
            
            result_keys = []
            result_vals = []
            
            for i in range(out_count):
                key_sig = getattr(dut, f'out_key_{i}')
                val_sig = getattr(dut, f'out_val_{i}')
                
                if is_value_defined(key_sig.value) and is_value_defined(val_sig.value):
                    result_keys.append(int(key_sig.value))
                    result_vals.append(int(val_sig.value))
                else:
                    raise TestFailure(f"Output {i} contains undefined value")
            
            result_dict = {}
            for key_packed, val in zip(result_keys, result_vals):
                key_str = ""
                for i in range(8):
                    char_code = (key_packed >> ((7 - i) * 8)) & 0xFF
                    if char_code > 32:
                        key_str += chr(char_code)
                    else:
                        key_str += " "
                key_str = key_str.rstrip()
                if key_str:
                    result_dict[key_str] = val
            
            expected_count = len(expected_dict)
            if out_count != expected_count:
                raise TestFailure(f"Expected {expected_count} results, got {out_count}")
            
            for key, expected_val in expected_dict.items():
                if key not in result_dict:
                    raise TestFailure(f"Key '{key}' not found in result")
                if result_dict[key] != expected_val:
                    raise TestFailure(f"Value mismatch for '{key}': expected {expected_val}, got {result_dict[key]}")
            
            if result_dict != expected_dict:
                raise TestFailure(f"Result mismatch: {result_dict} != {expected_dict}")
            
            cocotb.log.info(f"  Result: {result_dict} - PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL - {e}")
            failed += 1
    
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")