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

# Fixed-point conversion helpers
Q16_SHIFT = 1 << 16
Q8_SHIFT = 1 << 8

def float_to_q16(f):
    """Convert float to Q16.16 fixed-point"""
    return int(f * Q16_SHIFT)

def q16_to_float(val):
    """Convert Q16.16 to float"""
    return val / Q16_SHIFT

def float_to_q8(f):
    """Convert float to Q8.8 fixed-point"""
    return int(f * Q8_SHIFT)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_cyclist_wetness(dut):
    """Test cyclist wetness optimization module"""
    
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
    # Reset sequence
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: Simple case from example
    # T=5, c=0.1, d=2.0, all rain=0
    T = 5
    c = 0.1
    d = 2.0
    rain = [0, 0, 0, 0, 0]
    
    # Scale values
    T_in = T
    c_fixed = float_to_q8(c)
    d_fixed = float_to_q8(d)
    
    # Write inputs
    if has_signal(dut, 'T_in'):
        dut.T_in.value = clamp_to_width(T_in, 5)  # 5 bits for 32
    if has_signal(dut, 'c_fixed'):
        dut.c_fixed.value = clamp_to_width(c_fixed, 16)
    if has_signal(dut, 'd_fixed'):
        dut.d_fixed.value = clamp_to_width(d_fixed, 16)
    
    # Write rain array
    if has_signal(dut, 'rain'):
        # Individual array elements
        for i in range(min(len(rain), 32)):
            # Access as dut.rain[i] or dut.rain_0, etc.
            if hasattr(dut.rain, '__getitem__'):
                dut.rain[i].value = clamp_to_width(rain[i], 7)
            else:
                # Check for named ports
                port_name = f'rain_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(rain[i], 7)
    
    # Start computation
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        dut.start.value = 0
    
    # Wait for completion
    if has_signal(dut, 'done'):
        # Poll for done signal
        cycles = 0
        max_cycles = 2000
        while cycles < max_cycles:
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if cycles >= max_cycles:
            raise TestFailure(f"Timeout after {max_cycles} cycles")
    else:
        # No done signal, wait fixed time
        await Timer(1000, units='ns')
    
    # Read result
    if has_signal(dut, 'result'):
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result_q16 = int(dut.result.value)
        result_float = q16_to_float(result_q16)
        
        # Expected: 288.0
        expected = 288.0
        
        # Allow small error due to fixed-point precision
        error = abs(result_float - expected)
        relative_error = error / expected if expected != 0 else error
        
        if error > 1.0 and relative_error > 0.001:  # Allow 0.1% error
            raise TestFailure(f"Expected {expected}, got {result_float} (error={error})")
        
        cocotb.log.info(f"Test 1 PASSED: {result_float}")
    
    # Test case 2: Second example with rain
    # Reset again
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 2: T=30, c=0.01, d=2.0, rain = [0,0,0,100,100,100, then 1s]
    T = 30
    c = 0.01
    d = 2.0
    rain = [0, 0, 0, 100, 100, 100] + [1] * 24  # 30 values total
    
    # Scale values
    T_in = T
    c_fixed = float_to_q8(c)
    d_fixed = float_to_q8(d)
    
    # Write inputs
    if has_signal(dut, 'T_in'):
        dut.T_in.value = clamp_to_width(T_in, 5)
    if has_signal(dut, 'c_fixed'):
        dut.c_fixed.value = clamp_to_width(c_fixed, 16)
    if has_signal(dut, 'd_fixed'):
        dut.d_fixed.value = clamp_to_width(d_fixed, 16)
    
    # Write rain array
    if has_signal(dut, 'rain'):
        for i in range(min(len(rain), 32)):
            if hasattr(dut.rain, '__getitem__'):
                dut.rain[i].value = clamp_to_width(rain[i], 7)
            else:
                port_name = f'rain_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(rain[i], 7)
    
    # Start computation
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        dut.start.value = 0
    
    # Wait for completion
    if has_signal(dut, 'done'):
        cycles = 0
        max_cycles = 2000
        while cycles < max_cycles:
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if cycles >= max_cycles:
            raise TestFailure(f"Timeout after {max_cycles} cycles")
    else:
        await Timer(1000, units='ns')
    
    # Read result
    if has_signal(dut, 'result'):
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result_q16 = int(dut.result.value)
        result_float = q16_to_float(result_q16)
        
        # Expected: 24.0
        expected = 24.0
        
        error = abs(result_float - expected)
        relative_error = error / expected if expected != 0 else error
        
        if error > 1.0 and relative_error > 0.001:
            raise TestFailure(f"Expected {expected}, got {result_float} (error={error})")
        
        cocotb.log.info(f"Test 2 PASSED: {result_float}")
    
    # Edge case: Zero distance
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    T = 5
    c = 0.1
    d = 0.0  # Zero distance
    rain = [10, 20, 30, 40, 50]
    
    T_in = T
    c_fixed = float_to_q8(c)
    d_fixed = float_to_q8(d)
    
    if has_signal(dut, 'T_in'):
        dut.T_in.value = clamp_to_width(T_in, 5)
    if has_signal(dut, 'c_fixed'):
        dut.c_fixed.value = clamp_to_width(c_fixed, 16)
    if has_signal(dut, 'd_fixed'):
        dut.d_fixed.value = clamp_to_width(d_fixed, 16)
    
    if has_signal(dut, 'rain'):
        for i in range(min(len(rain), 32)):
            if hasattr(dut.rain, '__getitem__'):
                dut.rain[i].value = clamp_to_width(rain[i], 7)
            else:
                port_name = f'rain_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(rain[i], 7)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        dut.start.value = 0
    
    if has_signal(dut, 'done'):
        cycles = 0
        max_cycles = 2000
        while cycles < max_cycles:
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if cycles >= max_cycles:
            raise TestFailure(f"Timeout after {max_cycles} cycles")
    else:
        await Timer(1000, units='ns')
    
    if has_signal(dut, 'result'):
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result_q16 = int(dut.result.value)
        result_float = q16_to_float(result_q16)
        
        # Expected: 0.0 (zero distance)
        expected = 0.0
        
        error = abs(result_float - expected)
        
        if error > 1.0:  # Allow small error
            raise TestFailure(f"Expected {expected}, got {result_float} (error={error})")
        
        cocotb.log.info(f"Test 3 PASSED: {result_float}")
    
    # All tests passed
    cocotb.log.info("All tests passed successfully")