import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_count_occurance(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_in'): dut.char_in.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        ("letstdlenstdporstd", 3),
        ("truststdsolensporsd", 1),
        ("makestdsostdworthit", 2),
        ("stds", 1),
        ("", 0)
    ]

    for text, expected in test_cases:
        dut._log.info(f"Testing text: '{text}' (Expected: {expected})")
        
        # 1. Preload Buffer (Direct assignment to internal buffer array)
        # In hardware, this would be done via a loading state. 
        # For verification, we access the internal buffer array directly if it exists.
        # We assume the buffer is named 'buffer' internally.
        # If not accessible (e.g. defined in always block), we might need to simulate char_in.
        # To be robust, we check if we can access 'buffer' directly. If not, we use char_in method.
        
        char_list = [ord(c) for c in text]
        length = len(char_list)
        
        # Try to access internal buffer directly for speed
        if has_signal(dut, 'buffer'):
            for i in range(ARRAY_SIZE):
                val = char_list[i] if i < length else 0
                dut.buffer[i].value = clamp_to_width(val, DATA_WIDTH)
        else:
            # Fallback: Simulate streaming if buffer is not exposed
            # This is slower and requires start signal handling logic in DUT
            dut._log.warning("Internal buffer not exposed, assuming preloaded or handling via stream.")
            # For this benchmark, we assume direct buffer access is possible as per 'Acceptable' rules.
            # If the generated code hides the buffer, we'll fail here or need modification.
            pass
            
        # 2. Set Length (if len signal exists)
        if has_signal(dut, 'len'):
            dut.len.value = length
        
        # 3. Trigger Processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 4. Wait for Done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout waiting for done signal. Text: '{text}'")
        
        # 5. Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        dut._log.info(f"Result: {result}")
        if result != expected:
            raise TestFailure(f"Result mismatch for '{text}': Expected {expected}, got {result}")
        
        # Reset between tests if necessary (or just let pipeline clear)
        await RisingEdge(dut.clk)
