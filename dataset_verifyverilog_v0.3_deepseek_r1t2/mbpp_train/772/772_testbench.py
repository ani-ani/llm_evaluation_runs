import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_word_k_remover(dut):
    """
    Test word_k_remover module.
    The module processes one character per cycle.
    Input: Character stream (driven on char_in based on in_idx logic)
    Output: Character stream on char_out
    """
    
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases
    # Format: (String, K, Expected Result)
    test_cases = [
        ("The person is most value tet", 3, "person is most value"),
        ("If you told me about this ok", 4, "If you me about ok"),
        ("Forces of darkeness is come into the play", 4, "Forces of darkeness is the"),
    ]
    
    for test_idx, (test_str, k_val, expected) in enumerate(test_cases):
        
        dut._log.info(f"Running Test {test_idx+1}: '{test_str}' (K={k_val})")
        
        # Prepare Input Stream
        # In this design, we drive char_in. 
        # The module increments in_idx internally.
        # However, Verilog modules don't usually read from a 'stream' without an index.
        # The prompt I generated has `char_in` as input, but no address output.
        # This implies the testbench must know when the module needs data.
        # BUT, my Verilog code actually uses `in_idx` to track position.
        # And `char_in` is expected to be driven.
        # **Correction**: The module as written acts as a controller.
        # It doesn't generate a read address. It assumes external logic feeds `char_in`.
        # To make this testable, I must simulate the memory read.
        # I will add a helper loop that:
        # 1. Looks at `in_idx` (if exposed) OR
        # 2. Since `in_idx` is internal, I must rely on the module's interface.
        
        # **Wait**, the Verilog module uses `in_idx` but doesn't output it.
        # This is a problem for the testbench to feed data.
        # **ADJUSTMENT**: I will drive `char_in` based on a counter that tracks cycles,
        # assuming the module consumes `char_in` when `state` is READ_CHAR.
        # Or, simpler: I will rely on the module's `in_idx` logic.
        # Since `in_idx` is internal, I will modify my testbench to detect state 
        # or just blindly feed characters based on a simulation of the module's logic.
        
        # **Revised Strategy**: The module is a Mealy/Moore machine.
        # It expects `char_in` to be valid when it samples.
        # I will drive `char_in` by looking at the internal `in_idx`.
        # To do this, I need to probe the internal `in_idx`.
        # In Cocotb, I can access internal signals.
        
        chars = [ord(c) for c in test_str]
        
        dut.start.value = 1
        dut.k_len.value = k_val
        dut.str_len.value = len(test_str)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Output collection
        output_str = ""
        
        cycles = 0
        while True:
            # Feed Input Logic
            # We check if the module needs input.
            # Since `in_idx` is internal, we peek it.
            # If `in_idx` < `str_len`, we should drive `char_in`.
            # But the module samples `char_in` in state READ_CHAR.
            
            # Get internal state for debugging/driving
            # We assume we can access internal signals
            try:
                current_in_idx = int(dut.in_idx.value)
            except:
                current_in_idx = 0
            
            if current_in_idx < len(test_str):
                dut.char_in.value = chars[current_in_idx]
            else:
                dut.char_in.value = ord(' ') # Default
            
            await RisingEdge(dut.clk)
            cycles += 1
            
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Test {test_idx+1} Timeout")
            
            # Capture Output
            if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                char_val = int(dut.char_out.value)
                if char_val >= 32 and char_val <= 126:
                    output_str += chr(char_val)
                else:
                    output_str += " "
            
            # Check Done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Trim trailing space if any
        output_str = output_str.rstrip()
        
        if output_str != expected:
            raise TestFailure(f"Test {test_idx+1} Failed!\nExpected: '{expected}'\nGot:      '{output_str}'")
        
        dut._log.info(f"Test {test_idx+1} Passed. Result: '{output_str}'")
        
        # Reset for next test
        await reset_dut(dut)