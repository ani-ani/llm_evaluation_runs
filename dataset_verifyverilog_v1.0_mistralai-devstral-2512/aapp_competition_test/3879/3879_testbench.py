import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Setup parameters
DATA_WIDTH = 32
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 10000  # High due to sequential division

def normalize_val(v):
    """Python reference for normalization"""
    while v % 2 == 0:
        v //= 2
    while v % 3 == 0:
        v //= 3
    return v

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bid_checker(dut):
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.we.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        ([75, 150, 75, 50], True),  # Example 1
        ([100, 150, 250], False),   # Example 2
        ([1, 1], True),
        ([5, 6], False),
        ([2, 2, 5, 2], False),
    ]
    
    for vals, expected in test_cases:
        n = len(vals)
        dut._log.info(f"Testing {vals} -> Expected {'Yes' if expected else 'No'}")
        
        # Load data into internal array
        # We assume the DUT has an internal array or we write via we/idx_in/data_in
        # The spec says: data_in, idx_in, we
        for i, v in enumerate(vals):
            dut.we.value = 1
            dut.idx_in.value = i
            dut.data_in.value = clamp_to_width(v, DATA_WIDTH)
            await RisingEdge(dut.clk)
        
        dut.we.value = 0
        dut.len.value = n
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout for case {vals}")
            
        # Check result
        valid_signal = 0
        if has_signal(dut, 'valid'):
             valid_signal = int(dut.valid.value)
        elif has_signal(dut, 'result'):
             # If result is just the core value or status
             valid_signal = int(dut.result.value)
        else:
             raise TestFailure("No valid result signal found")
             
        is_yes = (valid_signal == 1)
        
        if is_yes != expected:
            raise TestFailure(f"Mismatch: got {'Yes' if is_yes else 'No'}, expected {'Yes' if expected else 'No'}")
            
        # Small delay between tests
        await Timer(50, units='ns')
