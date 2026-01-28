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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Testbench constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sabotage(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (input_array, expected_valid, description)
    # Case 1: All same, can change one to make unsorted
    test_cases = [
        ([20, 20, 20], True, "All equal, change first"),
        ([1, 99], False, "1 to 99, impossible"),
        ([10, 20, 30, 40], True, "1,2,3,4 scaled"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (inp_vals, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        try:
            # Write input array
            for i, v in enumerate(inp_vals):
                if i >= ARRAY_SIZE: break
                dut.__getattr__(f'arr_{i}').value = clamp_to_width(v, DATA_WIDTH)
            
            # Write n
            dut.n.value = len(inp_vals)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            else:
                await Timer(100, units='ns')
            
            # Check valid signal
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            got_valid = int(dut.valid.value) == 1
            
            if got_valid != exp_valid:
                raise TestFailure(f"Expected valid={exp_valid}, got {got_valid}")
            
            # If valid, check output array is unsorted
            if got_valid:
                out_vals = []
                for i in range(min(len(inp_vals), ARRAY_SIZE)):
                    if has_signal(dut, f'result_arr_{i}'):
                        val = int(getattr(dut, f'result_arr_{i}').value)
                        out_vals.append(val)
                    elif has_signal(dut, 'result_arr') and hasattr(dut.result_arr, '__getitem__'):
                        val = int(dut.result_arr[i].value)
                        out_vals.append(val)
                    else:
                        raise TestFailure("Cannot access result array")
                
                # Check unsorted
                is_sorted = all(out_vals[i] <= out_vals[i+1] for i in range(len(out_vals)-1))
                if is_sorted:
                    raise TestFailure(f"Result array {out_vals} is still sorted")
                
                # Check exactly one number changed
                changed_count = sum(1 for a, b in zip(inp_vals, out_vals) if a != b)
                if changed_count != 1:
                    raise TestFailure(f"Expected 1 change, got {changed_count}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")