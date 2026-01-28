import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
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

def sign_extend_to_width(v, src_bits, dst_bits):
    # If v is negative in src_bits, extend to dst_bits
    if v >= (1 << (src_bits - 1)):
        # Negative in src_bits
        return v | (~((1 << src_bits) - 1) & ((1 << dst_bits) - 1))
    return v

async def write_array(dut, name, vals, width):
    # Individual assignment for array elements
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            getattr(dut, f'{name}_{i}').value = from_signed(v, width)

def compute_expected(arr, n):
    """Compute expected sum using the formula"""
    total = 0
    for i in range(n):
        term = ((i + 1) * (n - i) + 1) // 2
        total += term * arr[i]
    return total

def clamp_signed(val, bits):
    """Clamp signed value to given bits"""
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    if val > max_val:
        return max_val
    if val < min_val:
        return min_val
    return val

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_odd_length_sum(dut):
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, length, expected_sum, description)
    test_cases = [
        ([1, 2, 4], 3, 14, "Test 1: [1,2,4] -> 14"),
        ([1, 2, 1, 2], 4, 15, "Test 2: [1,2,1,2] -> 15"),
        ([1, 7], 2, 8, "Test 3: [1,7] -> 8"),
        ([0, 0, 0, 0, 0], 5, 0, "Test 4: zeros"),
        ([10, 20, 30], 3, 140, "Test 5: [10,20,30]"),
        ([-1, 2, -3], 3, -2, "Test 6: negative values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        
        # Calculate expected with clamping to 16-bit signed
        clamped_expected = clamp_signed(expected, 16)
        
        try:
            # Write array values
            for idx in range(ARRAY_SIZE):
                if idx < length:
                    val = arr_vals[idx]
                    # Clamp to 8-bit signed and convert to unsigned for HDL
                    if val < -128: val = -128
                    if val > 127: val = 127
                    dut.__getattr__(f'arr_{idx}').value = from_signed(val, 8)
                else:
                    # Set unused elements to 0
                    dut.__getattr__(f'arr_{idx}').value = 0
            
            # Write length
            dut.len.value = length
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=200)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result_val = int(dut.result.value)
                # Convert from unsigned to signed for 16-bit result
                result_signed = to_signed(result_val, 16)
                
            else:
                # Combinational output
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result_val = int(dut.result.value)
                result_signed = to_signed(result_val, 16)
            
            cocotb.log.info(f"Result: {result_signed}, Expected: {clamped_expected}")
            
            if result_signed != clamped_expected:
                raise TestFailure(f"Expected {clamped_expected}, got {result_signed}")
            
            passed += 1
            cocotb.log.info(f"PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"\n{failed} tests failed, {passed} tests passed")
    else:
        cocotb.log.info(f"\nAll {passed} tests passed!")