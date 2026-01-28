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

def write_array_signed(dut, name, vals, width):
    """Write signed values to individual array elements."""
    for i, v in enumerate(vals):
        # Convert negative values to unsigned representation
        if v < 0:
            v_unsigned = v + (1 << width)
        else:
            v_unsigned = v
        dut.__getattr__(name)[i].value = clamp_to_width(v_unsigned, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_positives(dut):
    """Test the filter_positives module."""
    # Check if synchronous (has clock)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut, 2)
    
    # Test cases: (input_list, expected_output_list, description)
    test_cases = [
        ([-1, 2, -4, 5, 6], [2, 5, 6], "Basic test with negatives and positives"),
        ([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10], [5, 3, 2, 3, 3, 9, 123, 1], "Mixed positives, negatives, and zeros"),
        ([-1, -2, 4, 5, 6], [4, 5, 6], "Start with negatives, end with positives"),
        ([5, 3, -5, 2, 3, 3, 9, 0, 123, 1, -10], [5, 3, 2, 3, 3, 9, 123, 1], "Duplicate positive numbers"),
        ([-1, -2], [], "All negative"),
        ([], [], "Empty array"),
        ([0, -1, 0], [], "Zeros and negatives, no positives"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], "All positive (max size)"),
        ([-128, -127, 0, 1, 127], [1, 127], "Edge values (8-bit signed)"),
        ([1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8], [1, 2, 3, 4, 5, 6, 7, 8], "Alternating signs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Ensure input fits in 16 elements
            if len(inp) > 16:
                raise TestFailure(f"Input too long ({len(inp)} > 16)")
            
            # Write input array
            if has_signal(dut, 'arr_in'):
                write_array_signed(dut, 'arr_in', inp, 8)
            
            # Write input length
            if has_signal(dut, 'len_in'):
                dut.len_in.value = len(inp)
            
            if is_seq:
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, 50)  # Max 50 cycles for 16 elements
                
                # Check outputs
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("done signal not asserted")
                
                # Read output length
                if has_signal(dut, 'len_out'):
                    len_out_val = int(dut.len_out.value)
                else:
                    len_out_val = 0
                
                # Check length match
                if len_out_val != len(exp):
                    raise TestFailure(f"Length mismatch: expected {len(exp)}, got {len_out_val}")
                
                # Read output array
                result_values = []
                if has_signal(dut, 'result'):
                    for j in range(min(len_out_val, 16)):
                        val_unsigned = int(dut.result[j].value)
                        # Convert unsigned to signed for comparison
                        val_signed = to_signed(val_unsigned, 8)
                        result_values.append(val_signed)
                
                # Compare results
                if result_values != exp:
                    raise TestFailure(f"Result mismatch: expected {exp}, got {result_values}")
                
            else:
                # Combinational: small delay
                await Timer(100, units='ns')
                
                # Read outputs directly
                if has_signal(dut, 'len_out'):
                    len_out_val = int(dut.len_out.value)
                else:
                    len_out_val = 0
                
                if len_out_val != len(exp):
                    raise TestFailure(f"Length mismatch: expected {len(exp)}, got {len_out_val}")
                
                result_values = []
                if has_signal(dut, 'result'):
                    for j in range(min(len_out_val, 16)):
                        val_unsigned = int(dut.result[j].value)
                        val_signed = to_signed(val_unsigned, 8)
                        result_values.append(val_signed)
                
                if result_values != exp:
                    raise TestFailure(f"Result mismatch: expected {exp}, got {result_values}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
        
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")