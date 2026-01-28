import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_zebra_partition(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'read_done'): dut.read_done.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (input_string, expected_error, description)
    test_cases = [
        ("0010100", False, "Basic valid case"),
        ("111", True, "Starts with 1"),
        ("0", False, "Single 0"),
        ("1", True, "Single 1"),
        ("0101010101", True, "Ends with 1"),
        ("010100001", True, "Trailing 1"),
        ("000111000", False, "Multiple groups"),
        ("0000000000", False, "All zeros"),
    ]

    for s, should_error, desc in test_cases:
        cocotb.log.info(f"Testing: {desc} ({s})")
        
        # Reset for new test
        dut.start.value = 0
        dut.char_valid.value = 0
        dut.read_done.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for ready
        timeout = 0
        while not (has_signal(dut, 'ready') and int(dut.ready.value) == 1):
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                raise TestFailure("Module not ready within 100 cycles")
        
        # Send input stream
        dut.start.value = 1
        for char in s:
            # Wait for ready to be high
            while not (has_signal(dut, 'ready') and int(dut.ready.value) == 1):
                await RisingEdge(dut.clk)
            
            dut.char_in.value = int(char)
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
            dut.char_valid.value = 0
            
            # Wait one cycle to ensure processing
            await RisingEdge(dut.clk)
            
            if has_signal(dut, 'error') and int(dut.error.value) == 1:
                if not should_error:
                    raise TestFailure(f"Unexpected error for valid input '{s}'")
                # Break early if error detected
                break

        # Signal end of input
        dut.read_done.value = 1
        if has_signal(dut, 'ready') and int(dut.ready.value) == 1:
             await RisingEdge(dut.clk)
        dut.read_done.value = 0
        
        # Wait for done or error
        found_done = False
        error_flag = False
        for _ in range(2000): # Increased timeout for processing
            await RisingEdge(dut.clk)
            if has_signal(dut, 'error') and int(dut.error.value) == 1:
                error_flag = True
                break
            if has_signal(dut, 'done') and int(dut.done.value) == 1:
                found_done = True
                break
        
        if should_error:
            if not error_flag:
                raise TestFailure(f"Expected error for input '{s}' but none received")
            cocotb.log.info("Pass: Error detected as expected")
        else:
            if not found_done:
                raise TestFailure(f"Module did not finish for valid input '{s}'")
            if error_flag:
                raise TestFailure(f"Unexpected error for valid input '{s}'")
            
            # Verify output structure
            # Read k_out
            k = int(dut.k_out.value) if has_signal(dut, 'k_out') else 0
            cocotb.log.info(f"Number of subsequences: {k}")
            
            # Read stream
            total_elements = 0
            current_subseq_len = 0
            expected_indices = list(range(1, len(s)+1))
            received_indices = []
            
            while True:
                # Read li_out and idx_out
                if has_signal(dut, 'li_out'):
                    li = int(dut.li_out.value)
                    if li > 0:
                        cocotb.log.info(f"Subsequence length: {li}")
                        current_subseq_len = li
                        for _ in range(li):
                            await RisingEdge(dut.clk)
                            if has_signal(dut, 'idx_valid') and int(dut.idx_valid.value) == 1:
                                idx = int(dut.idx_out.value)
                                received_indices.append(idx)
                                cocotb.log.info(f"  Index: {idx}")
                            else:
                                raise TestFailure("Index not valid during read")
                        
                        # Check subseq_done
                        if has_signal(dut, 'subseq_done') and int(dut.subseq_done.value) == 1:
                            pass # Expected
                        else:
                            # Wait for it
                            await RisingEdge(dut.clk)
                            if has_signal(dut, 'subseq_done') and int(dut.subseq_done.value) == 1:
                                pass
                            else:
                                raise TestFailure("subseq_done not high after indices")
                        
                        total_elements += current_subseq_len
                    else:
                        break # li_out is 0 or undefined? Assume done.
                
                # Check overall done
                if has_signal(dut, 'done') and int(dut.done.value) == 1:
                    break
                
                await RisingEdge(dut.clk)
                
                # Safety break
                if total_elements > len(s):
                    raise TestFailure("Read more elements than input length")
            
            # Verify indices
            if sorted(received_indices) != expected_indices:
                 raise TestFailure(f"Indices mismatch. Got {sorted(received_indices)}, Expected {expected_indices}")
            
            cocotb.log.info(f"Pass: Successfully partitioned into {k} zebras")
