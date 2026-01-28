import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_IN_SIZE = 8
ARRAY_OUT_SIZE = 4
CLK_NS = 10
MAX_CYCLES = 100

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

async def write_array_in(dut, values):
    """Write input array elements individually"""
    for i in range(ARRAY_IN_SIZE):
        val = values[i] if i < len(values) else 0
        dut.arr_in[i].value = clamp_to_width(val, DATA_WIDTH)
    dut.arr_in_valid.value = 1

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    dut.arr_in_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_split_odds(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'start')
    
    if is_seq:
        cocotb.log.info("Testing sequential module")
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        cocotb.log.info("Testing combinational module")
        # For combinational, just set input and check
        pass
    
    # Test cases: (input_list, expected_output_list, expected_length)
    test_cases = [
        ([1,2,3,4,5,6,0,0], [1,3,5], 3),
        ([10,11,12,13,14,15,16,17], [11,13,15,17], 4),
        ([7,8,9,1,2,3,4,5], [7,9,1,3], 4),
        ([2,4,6,8,10,12,14,16], [], 0),
        ([-1,0,1,2,3,4,5,6], [-1,1,3,5], 4),  # Test negative odd
        ([0,0,0,0,0,0,0,0], [], 0),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_vals, expected_vals, expected_len) in enumerate(test_cases):
        desc = f"Input: {input_vals}"
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        
        try:
            # Write input
            for i in range(ARRAY_IN_SIZE):
                val = input_vals[i] if i < len(input_vals) else 0
                dut.arr_in[i].value = clamp_to_width(val, DATA_WIDTH)
            
            if is_seq:
                # Sequential processing
                dut.start.value = 1
                dut.arr_in_valid.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                dut.arr_in_valid.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result when done=1
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal undefined")
                
                if int(dut.done.value) != 1:
                    raise TestFailure(f"Done not asserted, value={dut.done.value}")
                
                # Read output array length
                if has_signal(dut, 'arr_out_len'):
                    out_len = int(dut.arr_out_len.value)
                    if out_len != expected_len:
                        raise TestFailure(f"Length mismatch: expected {expected_len}, got {out_len}")
                else:
                    # Count non-zero output elements
                    out_len = 0
                    for i in range(ARRAY_OUT_SIZE):
                        val = int(dut.arr_out[i].value)
                        if val != 0:
                            out_len += 1
                    if out_len != expected_len:
                        raise TestFailure(f"Length mismatch: expected {expected_len}, got {out_len}")
            else:
                # Combinational - immediate check
                await Timer(10, units='ns')
                
                # Read output array
                if has_signal(dut, 'arr_out_len'):
                    out_len = int(dut.arr_out_len.value)
                    if out_len != expected_len:
                        raise TestFailure(f"Length mismatch: expected {expected_len}, got {out_len}")
                
            # Check output array values
            for i in range(ARRAY_OUT_SIZE):
                if i < expected_len:
                    exp_val = expected_vals[i]
                else:
                    exp_val = 0
                
                out_val = int(dut.arr_out[i].value)
                # Convert from unsigned to signed if needed
                if out_val >= 128:  # If it looks like negative
                    out_val = out_val - 256
                
                if out_val != exp_val:
                    raise TestFailure(f"Index {i}: expected {exp_val}, got {out_val}")
            
            cocotb.log.info(f"  PASS: Output length={expected_len}, values={expected_vals}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")