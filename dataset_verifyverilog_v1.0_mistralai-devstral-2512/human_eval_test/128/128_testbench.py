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
    max_val = (1 << bits) - 1
    v = v & max_val if v >= 0 else ((1 << bits) + v) & max_val
    return v

def compute_expected(arr):
    if len(arr) == 0:
        return None, False
    
    # Product of signs
    sign_prod = 1
    for x in arr:
        if x == 0:
            sign_prod = 0
            break
        elif x > 0:
            sign_prod *= 1
        else:  # x < 0
            sign_prod *= -1
    
    # Sum of magnitudes
    mag_sum = sum(abs(x) for x in arr)
    
    # Result
    result = sign_prod * mag_sum
    return result, True

def write_array(dut, vals, width):
    """Write array elements individually"""
    if not hasattr(dut, 'arr'):
        # Try packed array or individual signals
        for i in range(8):
            if i < len(vals):
                port_name = f'arr_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(vals[i], width)
                else:
                    break
    else:
        # Packed array
        for i in range(min(8, len(vals))):
            dut.arr[i].value = clamp_to_width(vals[i], width)

def pack_array(vals, bits=8):
    """Pack array into single value for testing"""
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_prod_signs(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, 2, -4], -9, "Mix of positive and negative"),
        ([0, 1], 0, "Contains zero"),
        ([1, 1, 1, 2, 3, -1, 1], -10, "All positive except one negative"),
        ([], None, "Empty array"),
        ([2, 4, 1, 2, -1, -1, 9], 20, "Multiple negatives"),
        ([-1, 1, -1, 1], 4, "Alternating signs"),
        ([-1, 1, 1, 1], -4, "One negative"),
        ([-1, 1, 1, 0], 0, "Zero at end"),
    ]
    
    passed = failed = 0
    
    for i, (arr, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {arr}")
        
        try:
            # Clear inputs before writing
            if is_seq:
                dut.start.value = 0
                for j in range(8):
                    if hasattr(dut, 'arr') and j < len(dut.arr):
                        dut.arr[j].value = 0
                    else:
                        port_name = f'arr_{j}'
                        if has_signal(dut, port_name):
                            getattr(dut, port_name).value = 0
            
            # Write input array
            write_array(dut, arr, 8)
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = len(arr) & 0x07
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if is_seq:
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
                result_signed = to_signed(result, 16)  # Convert to signed for comparison
                
                # Check valid signal if exists
                if has_signal(dut, 'valid'):
                    valid = int(dut.valid.value)
                    if expected is None and valid != 0:
                        raise TestFailure(f"Expected valid=0 for empty array, got {valid}")
                    if expected is not None and valid != 1:
                        raise TestFailure(f"Expected valid=1 for non-empty array, got {valid}")
                
                # Check done signal
                if has_signal(dut, 'done'):
                    done = int(dut.done.value)
                    if done != 1:
                        raise TestFailure(f"Expected done=1 after computation, got {done}")
                
                if expected is None:
                    if result_signed != 0:
                        raise TestFailure(f"Expected result 0 for empty array, got {result_signed}")
                else:
                    if result_signed != expected:
                        raise TestFailure(f"Expected {expected}, got {result_signed}")
            else:
                # Combinational - result should be available immediately
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
                result_signed = to_signed(result, 16)
                
                if expected is None:
                    # For combinatorial, empty array might return 0 or undefined
                    if result_signed != 0 and result_signed != expected:
                        raise TestFailure(f"For empty array, expected 0 or None, got {result_signed}")
                else:
                    if result_signed != expected:
                        raise TestFailure(f"Expected {expected}, got {result_signed}")
            
            passed += 1
            cocotb.log.info(f"PASS: result={expected if expected is not None else 'None/0'}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
