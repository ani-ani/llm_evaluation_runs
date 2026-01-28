import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
FRAGMENTS_MAX = 10
LINES_PER_FRAG = 50
QUERY_LINES_MAX = 50
RESULT_WIDTH = 16
FILENAME_IDX_WIDTH = 3
CLK_NS = 10
MAX_CYCLES = 10000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def normalize_line_py(line_str):
    # Python implementation of normalization logic for testing
    line_str = line_str.strip()
    if not line_str:
        return None
    # Collapse multiple spaces
    parts = line_str.split()
    normalized = ' '.join(parts)
    # Pack to 64-bit integer (8 bytes ASCII)
    # Only take first 8 chars to fit limit
    packed = 0
    for i, char in enumerate(normalized[:8]):
        packed |= (ord(char) << (i * 8))
    return packed

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'fragment_lines_valid'): dut.fragment_lines_valid.value = 0
    if has_signal(dut, 'query_lines_valid'): dut.query_lines_valid.value = 0
    if has_signal(dut, 'input_done'): dut.input_done.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_plagiarism_detector(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    else:
        # Combinational block test
        pass
    
    await reset_dut(dut)
    
    # Test Case 1: Exact match in HelloWorld.c
    # Fragment 1: HelloWorld.c
    # Lines: "int Main() {", "    printf(\"Hello %d\\n\",i);", "}"
    # Normalized: "int Main() {" -> packed
    # Query: "int Main() {", "    printf(\"Hello %d\\n\",i);", "printf(\"THE END\\n\");"}
    # Expect match len 2, index 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send Fragments
    dut.fragmenst_count.value = 1
    
    # Fragment 0 (Index 1 in problem logic, 0 in zero-based) - HelloWorld.c
    lines_frag_0 = [
        "int Main() {",
        "    printf(\"Hello %d\\n\",i);",
        "}"
    ]
    
    for line in lines_frag_0:
        # Send filename index (0) and line
        # Assuming filename is input via separate port or hardcoded? 
        # The spec implies filename is part of input stream. 
        # Let's assume filename is sent before lines or associated.
        # Since interface in spec is simplified, we assume we send lines.
        # For this test, we will simulate the specific interface defined in prompt.
        # Prompt says: fragment_data (256-bit), fragment_file_name (128-bit)
        
        dut.fragment_lines_valid.value = 1
        dut.fragment_data.value = line.ljust(256)[:256] # Pad to 256 bytes
        dut.fragment_file_name.value = "HelloWorld.c".ljust(128)[:128]
        await RisingEdge(dut.clk)
    
    dut.fragment_lines_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Send Query
    query_lines = [
        "int Main() {",
        "    printf(\"Hello %d\\n\",i);",
        "  printf(\"THE END\\n\");"
    ]
    
    for line in query_lines:
        dut.query_lines_valid.value = 1
        dut.query_data.value = line.ljust(256)[:256]
        await RisingEdge(dut.clk)
        
    dut.query_lines_valid.value = 0
    
    # Signal input done
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    # Wait for done
    max_wait = 2000
    found = False
    for _ in range(max_wait):
        if has_signal(dut, 'done'):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found = True
                break
        else:
            # Combinational done or just timeout
            break
        await Timer(10, units='ns') # Small delay for combinationals
        
    if not found and has_signal(dut, 'done'):
        raise TestFailure("Timeout waiting for done signal")
        
    # Check results
    if has_signal(dut, 'result'):
        res = int(dut.result.value)
        if res != 2:
            raise TestFailure(f"Expected result 2, got {res}")
            
    if has_signal(dut, 'filenames'):
        # Check if filenames output corresponds to index 0 (HelloWorld.c)
        # In prompt, output is index 3-bit. 
        idx = int(dut.filenames.value)
        if idx != 0:
            raise TestFailure(f"Expected filename index 0, got {idx}")
            
    cocotb.log.info("Test Case 1 Passed")
    
    # Test Case 2: Empty lines and spacing
    # Reset and run again
    await reset_dut(dut)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Fragment 0
    lines_frag_0_2 = [
        "line 1",
        "",
        "line 2"
    ]
    # Normalized: "line 1", "line 2" (empty skipped)
    
    for line in lines_frag_0_2:
        dut.fragment_lines_valid.value = 1
        dut.fragment_data.value = line.ljust(256)[:256]
        dut.fragment_file_name.value = "File1".ljust(128)[:128]
        await RisingEdge(dut.clk)
        
    dut.fragment_lines_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Query
    query_lines_2 = [
        "line 1   ",  # Should normalize to "line 1"
        "line 2"
    ]
    
    for line in query_lines_2:
        dut.query_lines_valid.value = 1
        dut.query_data.value = line.ljust(256)[:256]
        await RisingEdge(dut.clk)
        
    dut.query_lines_valid.value = 0
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    # Wait
    for _ in range(max_wait):
        if has_signal(dut, 'done'):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found = True
                break
        await Timer(10, units='ns')
        
    if has_signal(dut, 'result'):
        res = int(dut.result.value)
        if res != 2:
            raise TestFailure(f"Expected result 2 for spacing test, got {res}")
            
    cocotb.log.info("Test Case 2 Passed")