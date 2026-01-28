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

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

async def write_array(dut, name, vals, width):
    """Write array elements individually to avoid syntax error"""
    for i in range(min(len(vals), ARRAY_SIZE)):
        if has_signal(dut, f'{name}_{i}'):
            getattr(dut, f'{name}_{i}').value = clamp_to_width(vals[i], width)
        else:
            # Assume array access style
            dut.__getattr__(name)[i].value = clamp_to_width(vals[i], width)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal or timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT synchronously"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_digit_sum(dut):
    """Test digit sum computation"""
    # Check if we have clock signals
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - still need to wait for propagation
        await Timer(100, units='ns')
    
    # Test cases: (input_numbers, expected_sum, description)
    # For ASCII array representation
    test_cases = [
        # Test 1: [10, 2, 56] -> '1','0','2','5','6' -> 1+0+2+5+6 = 14
        ([0x31, 0x30, 0x32, 0x35, 0x36, 0x20, 0x20, 0x20], 14, "[10,2,56] -> digits only"),
        # Test 2: [10,20,4,5,'b',70,'a'] -> filter 'b','a' -> 1+0+2+0+4+5+7+0 = 19
        ([0x31, 0x30, 0x32, 0x30, 0x34, 0x35, 0x62, 0x37, 0x30, 0x61, 0x20, 0x20], 19, "with letters b,a"),
        # Test 3: [10,20,-4,5,-70] -> skip '-', sum absolute digits: 1+0+2+0+4+5+7+0 = 19
        ([0x31, 0x30, 0x32, 0x30, 0x2D, 0x34, 0x35, 0x2D, 0x37, 0x30, 0x20, 0x20], 19, "with negatives")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (ascii_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        try:
            # Write array elements
            if is_seq:
                # For sequential design
                await write_array(dut, 'arr', ascii_vals, DATA_WIDTH)
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
            else:
                # Combinational - set inputs and wait for propagation
                await write_array(dut, 'arr', ascii_vals, DATA_WIDTH)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Final verdict
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")

# Additional test for edge cases
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Edge case: all non-digits
    edge_cases = [
        ([0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68], 0, "All letters"),
        ([0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30], 0, "All zeros"),
        ([0x2D, 0x2B, 0x20, 0x2D, 0x2B, 0x20, 0x2D, 0x2B], 0, "Only symbols"),
    ]
    
    for idx, (ascii_vals, expected, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge Test {idx+1}: {desc}")
        try:
            if is_seq:
                await write_array(dut, 'arr', ascii_vals, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = int(dut.result.value)
            else:
                await write_array(dut, 'arr', ascii_vals, DATA_WIDTH)
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise TestFailure(f"Edge case failed")
    
    cocotb.log.info("All edge cases passed")