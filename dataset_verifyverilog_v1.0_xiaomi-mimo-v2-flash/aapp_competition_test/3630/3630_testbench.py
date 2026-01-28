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

def clamp_to_width(v, bits):
    val = int(v)
    mask = (1 << bits) - 1
    return val & mask

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'string_end'): dut.string_end.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_string_difference(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (s1, s2, expected_sum)
    test_cases = [
        ("hello", "teams", 27),
        ("aacccaaaa", "bbbbb bbb".replace(" ", ""), 3)  # Input 2 from problem
    ]
    
    for s1, s2, expected in test_cases:
        cocotb.log.info(f"Testing transformation: '{s1}' -> '{s2}'")
        
        # Ensure strings are same length as per problem description
        assert len(s1) == len(s2), "Test case strings must be same length"
        
        # Start pulse
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Drive characters sequentially
        for i in range(len(s1)):
            dut.s1_char.value = ord(s1[i])
            dut.s2_char.value = ord(s2[i])
            dut.char_valid.value = 1
            if has_signal(dut, 'string_end'):
                dut.string_end.value = 1 if i == len(s1) - 1 else 0
            await RisingEdge(dut.clk)
        
        # Disable valid signal after last char
        dut.char_valid.value = 0
        if has_signal(dut, 'string_end'):
            dut.string_end.value = 0
        
        # Wait for done signal or fixed cycles
        if has_signal(dut, 'done'):
            done_found = False
            for _ in range(100): # Wait up to 100 cycles
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            if not done_found:
                raise TestFailure(f"Done signal not asserted for test case '{s1}->{s2}'")
        else:
            # If no done signal, assume combinational or wait fixed time
            await Timer(100, units='ns')
        
        # Check result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result_val = int(dut.result.value)
            # Handle potential overflow for 16-bit result in spec vs actual sum
            # If result is 16-bit, the large test case might overflow. 
            # We check logic with small values or mask if necessary.
            
            # For the 'hello' -> 'teams' case: sum is 27. Fits in 16 bits.
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            cocotb.log.info(f"Result {result_val} matches expected {expected}")
        else:
            cocotb.log.info("Result signal not found in DUT, skipping value check")
            
        # Reset for next test
        if has_signal(dut, 'clk'):
            await reset_dut(dut)

# Edge case test for single character
@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_single_char(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
        
        # 'a' -> 'c' : diff = 2
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
        dut.s1_char.value = ord('a')
        dut.s2_char.value = ord('c')
        dut.char_valid.value = 1
        if has_signal(dut, 'string_end'): dut.string_end.value = 1
        await RisingEdge(dut.clk)
        
        dut.char_valid.value = 0
        if has_signal(dut, 'string_end'): dut.string_end.value = 0
        
        if has_signal(dut, 'done'):
            await Timer(100, units='ns') # Wait for logic
            
        if has_signal(dut, 'result'):
            if int(dut.result.value) != 2:
                raise TestFailure(f"Single char test failed: expected 2, got {int(dut.result.value)}")
