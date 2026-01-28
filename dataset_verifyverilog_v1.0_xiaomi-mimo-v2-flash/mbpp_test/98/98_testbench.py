import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed_16(v):
    """Convert unsigned 16-bit to signed (Python)"""
    if v >= 32768:
        return v - 65536
    return v

def from_signed_16(v):
    """Convert signed to unsigned 16-bit for assignment"""
    if v < 0:
        return v + 65536
    return v

def fixed_to_float(val_32bit):
    """Convert Q32.0 to float for comparison"""
    # This is problematic - we need Q16.16
    # Let's interpret as Q16.16
    if val_32bit >= 2**31:
        signed_val = val_32bit - 2**32
    else:
        signed_val = val_32bit
    return signed_val / (1 << 16)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_array(dut, values, length):
    """Write input values to the data_in array (16 elements)"""
    # Clear unused positions with 0
    for i in range(16):
        if i < len(values):
            val = from_signed_16(values[i])
        else:
            val = 0
        dut.data_in[i].value = clamp_to_width(val, 16)
    # Set length
    dut.length.value = length

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_multiply_and_divide(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - set inputs directly
        await Timer(10, units='ns')
    
    # Test cases: (input_values, expected_result)
    # Expected results from Python function:
    # multiply_num((8, 2, 3, -1, 7)) / 5 = (8*2*3*-1*7)/5 = -336/5 = -67.2
    # multiply_num((-10,-20,-30)) / 3 = (-10*-20*-30)/3 = -6000/3 = -2000.0
    # multiply_num((19,15,18)) / 3 = (19*15*18)/3 = 5130/3 = 1710.0
    
    test_cases = [
        ((8, 2, 3, -1, 7), 5, -67.2, "5 positive/negative"),
        ((-10, -20, -30), 3, -2000.0, "All negative"),
        ((19, 15, 18), 3, 1710.0, "All positive"),
        ((1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1), 16, 1.0, "All ones"),
        ((2, 2, 2, 2, 2), 5, 6.4, "Small numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            if is_seq:
                # Write inputs
                await write_input_array(dut, input_vals, length)
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result_raw = int(dut.result.value)
                
                # Convert Q16.16 to float
                if result_raw >= 2**31:  # Negative in 32-bit signed
                    result_signed = result_raw - 2**32
                else:
                    result_signed = result_raw
                result_float = result_signed / (1 << 16)
                
            else:
                # Combinational: set inputs and read output
                await write_input_array(dut, input_vals, length)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result_raw = int(dut.result.value)
                if result_raw >= 2**31:
                    result_signed = result_raw - 2**32
                else:
                    result_signed = result_raw
                result_float = result_signed / (1 << 16)
            
            # Check with tolerance (fixed-point has 1/65536 precision)
            rel_error = abs(result_float - expected) / abs(expected)
            
            if rel_error <= 0.001:  # 0.1% tolerance
                cocotb.log.info(f"PASS: {desc} - Result: {result_float:.4f}, Expected: {expected:.4f}")
                passed += 1
            else:
                raise TestFailure(
                    f"Result mismatch - Got: {result_float:.4f}, Expected: {expected:.4f}, "
                    f"Error: {rel_error*100:.2f}% > 0.1%"
                )
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    # Verify done signal timing
    if is_seq:
        cocotb.log.info("Testing done signal timing...")
        # Quick test to ensure done pulses correctly
        await write_input_array(dut, (2, 3), 2)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done_pulse = 0
        for _ in range(10):
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                done_pulse += 1
        
        if done_pulse != 1:
            raise TestFailure(f"Done should pulse exactly once, got {done_pulse} times")
        
        # Check that done is 0 after reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        if int(dut.done.value) != 0:
            raise TestFailure("Done should be 0 after reset")
        if int(dut.result.value) != 0:
            raise TestFailure(f"Result should be 0 after reset, got {int(dut.result.value)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All tests passed! ({passed}/{passed + failed})")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    # Test edge cases
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test single element (no division needed)
    test_cases = [
        ((42,), 1, 42.0, "Single element"),
        ((-5,), 1, -5.0, "Single negative"),
        ((0,), 1, 0.0, "Single zero"),
        ((255, 255), 2, 65025.0, "Large numbers"),  # 255*255/2 = 32512.5, but 255*255 = 65025
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Edge Test {i+1}: {desc}")
        
        try:
            if is_seq:
                await write_input_array(dut, input_vals, length)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                result_raw = int(dut.result.value)
                if result_raw >= 2**31:
                    result_signed = result_raw - 2**32
                else:
                    result_signed = result_raw
                result_float = result_signed / (1 << 16)
            else:
                await write_input_array(dut, input_vals, length)
                await Timer(100, units='ns')
                result_raw = int(dut.result.value)
                if result_raw >= 2**31:
                    result_signed = result_raw - 2**32
                else:
                    result_signed = result_raw
                result_float = result_signed / (1 << 16)
            
            rel_error = abs(result_float - expected) / (abs(expected) + 1e-9)
            
            if rel_error <= 0.01:  # 1% tolerance for edge cases
                cocotb.log.info(f"PASS: {desc} - Result: {result_float:.4f}, Expected: {expected:.4f}")
                passed += 1
            else:
                raise TestFailure(
                    f"Result mismatch - Got: {result_float:.4f}, Expected: {expected:.4f}, "
                    f"Error: {rel_error*100:.2f}%"
                )
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} edge case tests failed")
    
    cocotb.log.info(f"All edge case tests passed! ({passed}/{passed + failed})")
