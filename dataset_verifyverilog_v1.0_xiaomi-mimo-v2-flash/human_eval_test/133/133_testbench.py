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

def float_to_q88(f):
    """Convert float to Q8.8 fixed-point"""
    return int(f * 256)

def ceiling_q88(val):
    """Compute ceiling of Q8.8 value"""
    # val is 16-bit signed in Q8.8 format
    sign = (val >> 15) & 1
    integer = (val >> 8) & 0x7F  # 7 bits, signed via sign extension later
    fractional = val & 0xFF
    
    # Sign extend integer to 16 bits
    if sign:
        integer = -128 + (integer & 0x7F)
    else:
        integer = integer
    
    if sign == 0:  # positive
        if fractional > 0:
            return integer + 1
        else:
            return integer
    else:  # negative
        if fractional == 0:
            return integer
        else:
            return integer + 1  # ceiling of negative moves toward zero

async def write_array(dut, vals, width=16):
    """Write array elements individually"""
    for i, v in enumerate(vals):
        dut.data_in[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_squares(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases: list of (input_floats, expected_result, description)
    test_cases = [
        ([1, 2, 3], 14, "integers 1,2,3"),
        ([1.0, 2, 3], 14, "mixed 1.0,2,3"),
        ([1, 3, 5, 7], 84, "odd numbers"),
        ([1.4, 4.2, 0], 29, "example 1.4,4.2,0"),
        ([-2.4, 1, 1], 6, "negative -2.4,1,1"),
        ([100, 1, 15, 2], 10230, "larger numbers"),
        ([10000, 10000], 200000000, "large numbers"),
        ([-1.4, 4.6, 6.3], 75, "negative decimals"),
        ([-1.4, 17.9, 18.9, 19.9], 1086, "mixed negatives"),
        ([0], 0, "single zero"),
        ([-1], 1, "single negative one"),
        ([-1, 1, 0], 2, "edge cases")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_floats, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - input={input_floats}")
        
        try:
            # Convert floats to Q8.8
            input_q88 = [float_to_q88(x) for x in input_floats]
            
            # Write array
            if is_seq:
                dut.len.value = len(input_q88)
                await write_array(dut, input_q88, 16)
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                        if int(dut.done.value) == 1:
                            done = True
                            break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for done")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                # Convert to signed if needed
                if has_signal(dut, 'result'):
                    # Check width of result
                    result = to_signed(result, 32)
            else:
                # Combinational
                dut.len.value = len(input_q88)
                await write_array(dut, input_q88, 16)
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                result = to_signed(result, 32)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
