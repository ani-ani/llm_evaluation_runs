import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
KEY_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 20

# Helper functions from spec
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

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_dict_sum(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational: just wait
        await Timer(10, units='ns')
    
    # Test cases based on Python examples
    # {'a': 100, 'b':200, 'c':300} -> keys: 97,98,99; vals: 100,200,300; sum=600
    # {'a': 25, 'b':18, 'c':45} -> sum=88
    # {'a': 36, 'b':39, 'c':49} -> sum=124
    
    test_cases = [
        (['a', 'b', 'c'], [100, 200, 300], 3, 600, "basic"),
        (['a', 'b', 'c'], [25, 18, 45], 3, 88, "small_vals"),
        (['a', 'b', 'c'], [36, 39, 49], 3, 124, "medium_vals"),
        ([], [], 0, 0, "empty_dict"),
        (['x'], [65535], 1, 65535, "max_value"),
        (['z'], [0], 1, 0, "zero_value")
    ]
    
    passed = 0
    failed = 0
    
    for i, (keys, vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Prepare data
            # Keys are ASCII codes
            key_vals = [ord(k) if k else 0 for k in keys]
            # Pad to ARRAY_SIZE
            while len(key_vals) < ARRAY_SIZE:
                key_vals.append(0)
            while len(vals) < ARRAY_SIZE:
                vals.append(0)
            
            # Write inputs
            if has_signal(dut, 'keys'):
                # Assume keys is 2D: keys[i] is 8-bit
                for j in range(ARRAY_SIZE):
                    if has_signal(dut, f'keys_{j}'):
                        getattr(dut, f'keys_{j}').value = clamp_to_width(key_vals[j], KEY_WIDTH)
                    else:
                        # Try direct array access if supported by simulator
                        try:
                            dut.keys[j].value = clamp_to_width(key_vals[j], KEY_WIDTH)
                        except:
                            pass
            
            if has_signal(dut, 'values'):
                for j in range(ARRAY_SIZE):
                    if has_signal(dut, f'values_{j}'):
                        getattr(dut, f'values_{j}').value = clamp_to_width(vals[j], DATA_WIDTH)
                    else:
                        try:
                            dut.values[j].value = clamp_to_width(vals[j], DATA_WIDTH)
                        except:
                            pass
            
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)
            
            # Trigger
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    # If no start signal, it might be always on or triggered by inputs
                    await RisingEdge(dut.clk)
                
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Done signal did not assert within {MAX_CYCLES} cycles")
            else:
                # Combinational: just wait for result to stabilize
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")