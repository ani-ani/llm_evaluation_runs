import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stochastic_scheduling(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("4\n1 1 7\n3 2 3\n5 1 4\n6 10 10\n", 2.125),
        ("5\n1 1 7\n1 1 6\n3 2 3\n5 1 4\n6 10 10\n", 2.29166667),
    ]
    
    for idx, (input_str, expected) in enumerate(test_cases):
        # Parse input
        lines = input_str.strip().split('\n')
        n = int(lines[0])
        hearings = []
        for i in range(n):
            parts = lines[i+1].split()
            s, a, b = int(parts[0]), int(parts[1]), int(parts[2])
            hearings.append((s, a, b))
        
        # Set n
        dut.n.value = n
        
        # Initialize all hearing inputs to 0
        for i in range(8):
            setattr(dut, f's{i}', 0)
            setattr(dut, f'a{i}', 0)
            setattr(dut, f'b{i}', 0)
        
        # Set actual hearings
        for i, (s, a, b) in enumerate(hearings):
            setattr(dut, f's{i}', s)
            setattr(dut, f'a{i}', a)
            setattr(dut, f'b{i}', b)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Test {idx}: Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {idx}: Result is undefined")
        
        result_q16_16 = int(dut.result.value)
        result_float = result_q16_16 / 65536.0
        
        # Compare
        if abs(result_float - expected) > 1e-3:
            raise TestFailure(f"Test {idx}: Expected {expected}, got {result_float}")
        else:
            dut._log.info(f"Test {idx}: PASS (result={result_float})")