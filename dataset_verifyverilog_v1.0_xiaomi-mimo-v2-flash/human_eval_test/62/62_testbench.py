import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
OUTPUT_WIDTH = 12
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_derivative(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        if has_signal(dut, 'start'): dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        ([3, 1, 2, 4, 5], 5, [1, 4, 12, 20], 4, "len=5"),
        ([1, 2, 3], 3, [2, 6], 2, "len=3"),
        ([3, 2, 1], 3, [2, 2], 2, "len=3 symmetric"),
        ([3, 2, 1, 0, 4], 5, [2, 2, 0, 16], 4, "len=5 with zero"),
        ([1], 1, [], 0, "len=1 constant"),
        ([0, 0, 0, 0, 0], 5, [0, 0, 0, 0], 4, "all zeros"),
    ]
    
    passed = failed = 0
    
    for i, (coeffs, in_len, expected, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write coefficients
            for idx, val in enumerate(coeffs):
                if idx < MAX_LEN:
                    dut.coeff[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(in_len, 4)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_seen = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_seen = True
                        break
                
                if not done_seen:
                    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
            else:
                await Timer(100, units='ns')
            
            # Check result_len
            if has_signal(dut, 'result_len'):
                result_len = int(dut.result_len.value)
                if result_len != exp_len:
                    raise TestFailure(f"result_len: expected {exp_len}, got {result_len}")
            
            # Check results
            if exp_len > 0:
                for idx in range(exp_len):
                    if not has_signal(dut, f'result_{idx}') and not hasattr(dut.result[idx], 'value'):
                        raise TestFailure(f"Missing result[{idx}] signal")
                    
                    if has_signal(dut, f'result_{idx}'):
                        result_val = int(getattr(dut, f'result_{idx}').value)
                    else:
                        result_val = int(dut.result[idx].value)
                    
                    # Handle signed output
                    if OUTPUT_WIDTH <= 8:
                        result_val_signed = to_signed(result_val, OUTPUT_WIDTH)
                    else:
                        # For widths >8, to_signed expects proper width
                        result_val_signed = result_val if result_val < (1 << (OUTPUT_WIDTH-1)) else result_val - (1 << OUTPUT_WIDTH)
                    
                    if result_val_signed != expected[idx]:
                        raise TestFailure(f"result[{idx}]: expected {expected[idx]}, got {result_val_signed}")
            
            # Verify non-result positions are zero
            for idx in range(exp_len, MAX_LEN):
                if has_signal(dut, f'result_{idx}'):
                    val = int(getattr(dut, f'result_{idx}').value)
                    if val != 0:
                        raise TestFailure(f"Non-output result[{idx}] should be 0, got {val}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result_len={exp_len}, results={expected}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")