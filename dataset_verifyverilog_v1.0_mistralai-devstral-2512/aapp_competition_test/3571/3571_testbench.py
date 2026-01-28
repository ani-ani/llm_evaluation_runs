import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 20000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to load text into the simplified RAM interface
async def load_text_lines(dut, lines, max_len=80):
    dut._log.info(f"Loading {len(lines)} lines")
    # Assuming interface: input_ram_addr (5 bit), input_ram_data (80 bit), input_ram_write (1 bit)
    dut.input_ram_write.value = 0
    await RisingEdge(dut.clk)
    
    for i, line in enumerate(lines):
        dut.input_ram_addr.value = i
        # Convert string to integer bits for 80-bit vector (8 chars per 10-bit chunk isn't needed, let's do 80 bits simply)
        # To be simple, let's assume 80 chars * 8 bits = 640 bits. Too big. 
        # Constraint: Use 80-bit width. We will pack 10 chars into 80 bits (8 bits each).
        # Actually, let's just pass the ASCII bytes into the top module simulation if it's a structural testbench.
        # Since this is a generation prompt, we assume the DUT has an input mechanism.
        
        # Let's pack the line into 80 bits (10 chars) or just use the first 10 chars if line is longer? 
        # The problem says "up to 80 chars". Let's assume the DUT expects 80 bits (10 chars) for simplicity in this constrained problem, or we map 1:1.
        # Let's map 1:1. 80 bits = 10 bytes. 
        # If the line is longer, we truncate. 
        # To be safe for the spec, let's pack 8 chars (64 bits) or just use 80 bits.
        # Let's use 80 bits. We will pack the first 10 characters into 80 bits (8 bits each).
        
        val = 0
        chars = line[:10].encode('ascii')
        for j, c in enumerate(chars):
            val |= c << (j * 8)
        dut.input_ram_data.value = val
        dut.input_ram_write.value = 1
        await RisingEdge(dut.clk)
        dut.input_ram_write.value = 0
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_ancient_viewport(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Sample Input 1
    W, H, F = 24, 5, 8
    text_lines_raw = [
        "Lorem ipsum dolor sit amet consectetur adipisicing elit sed do",
        "eiusmod tempor incididunt ut labore et dolore magna aliqua Ut enim ad",
        "minim veniam quis nostrud exercitation ullamco laboris nisi ut",
        "aliquip ex ea commodo consequat Duis aute irure dolor in",
        "reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla",
        "pariatur Excepteur sint occaecat cupidatat non proident sunt in",
        "culpa qui officia deserunt mollit anim id est laborum"
    ]
    N = len(text_lines_raw)
    
    dut._log.info(f"Config: W={W}, H={H}, F={F}, N={N}")
    
    # Set Configuration
    dut.W.value = W
    dut.H.value = H
    dut.F.value = F
    dut.N.value = N
    
    # Load Text
    await load_text_lines(dut, text_lines_raw)
    
    # Start Processing
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for Done
    cycles = 0
    while True:
        await RisingEdge(dut.clk)
        if cycles > MAX_CYCLES:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
        
    # Verify Output Stream
    # Since we can't easily dump the whole window in a simple testbench without a buffer,
    # we will assume the DUT outputs characters sequentially.
    # We need to reconstruct the visual frame.
    
    # Expected Output (from example)
    expected = [
        "+------------------------+-+",
        "|exercitation ullamco    |^|",
        "|laboris nisi ut aliquip | |",
        "|ex ea commodo consequat |X|",
        "|Duis aute irure dolor in| |",
        "|reprehenderit in        |v|",
        "+------------------------+-+"
    ]
    
    # Collect output
    output_chars = []
    if has_signal(dut, 'output_char') and has_signal(dut, 'output_valid'):
        # Check if output is valid. 
        # Note: In simple stream, valid might be high only for 1 cycle or continuous.
        # We'll assume continuous stream until done drops (or we sample for a duration).
        # Let's check the signal values at the current edge or next.
        
        # For this testbench, we will sample for a reasonable number of cycles
        for _ in range(200):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
                char_code = int(dut.output_char.value)
                if 32 <= char_code < 128:
                    output_chars.append(chr(char_code))
                else:
                    output_chars.append('?')
            else:
                break
                
    # Join and compare
    output_str = "".join(output_chars)
    dut._log.info(f"Generated Output:\n{output_str}")
    
    # Verify against expected (ignoring exact whitespace padding differences if any)
    # We check that the key lines are present and the structure matches
    lines = output_str.strip().split('\n')
    if len(lines) != len(expected):
         raise TestFailure(f"Line count mismatch. Expected {len(expected)}, got {len(lines)}")
    
    for i, (actual, exp) in enumerate(zip(lines, expected)):
        if actual != exp:
            raise TestFailure(f"Line {i} mismatch.\nExp: '{exp}'\nGot: '{actual}'")
            
    dut._log.info("Test Passed!")
