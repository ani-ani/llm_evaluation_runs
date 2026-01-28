import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

# Helper to convert test case strings to ASCII stream
def string_to_ascii_stream(s):
    return [ord(c) for c in s]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fruit_distribution(dut):
    """Test the fruit_distribution module with string parsing."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.write_en.value = 0
    dut.total.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases: (String, Total, Expected Mangoes)
    test_cases = [
        ("5 apples and 6 oranges", 19, 8),
        ("5 apples and 6 oranges", 21, 10),
        ("0 apples and 1 oranges", 3, 2),
        ("1 apples and 0 oranges", 3, 2),
        ("2 apples and 3 oranges", 100, 95),
        ("2 apples and 3 oranges", 5, 0),  # Result is negative or zero
        ("1 apples and 100 oranges", 120, 19)
    ]
    
    passed = 0
    total_tests = len(test_cases)
    
    for i, (s, total, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: String='{s}', Total={total}, Expected={expected}")
        
        # 1. Load String into Buffer
        ascii_stream = string_to_ascii_stream(s)
        
        # Reset buffer pointer logic by just pulsing write_en sequentially
        # We assume the module has an internal pointer or we write to indices
        # The prompt specifies 'write_en' and 'char_in'. It implies an internal FIFO or Index.
        # To be safe with the prompt "load char_in", we will assume the design has an internal index counter.
        
        # Let's verify if the design has an index input based on the prompt logic check.
        # The prompt says: "input write_en: High to write char_in to internal buffer."
        # This implies an internal pointer. We need to check if the prompt actually included an index.
        # Re-reading the prompt logic I wrote: 
        # "input write_en: High to write char_in to internal buffer."
        # I missed an index. If I don't provide an index, the testbench can't easily load arbitrary strings.
        # HOWEVER, the prompt logic says "Treat strings as fixed-width byte arrays".
        # Let's check the Prompt section again. I updated it to:
        # "input [4:0] char_valid: High to load char_data"
        # Wait, I need to finalize the Prompt string.
        
        # Let's assume the Prompt I wrote asks for an internal RAM addressed by a counter.
        # The testbench will need to clock in characters.
        
        # Re-reading my Prompt Idea:
        # Inputs: char_in, write_en.
        # This implies sequential loading.
        
        for char in ascii_stream:
            dut.char_in.value = char
            dut.write_en.value = 1
            await RisingEdge(dut.clk)
            dut.write_en.value = 0
            # Small delay for setup if needed
            # await RisingEdge(dut.clk) # Optional: wait 1 cycle per char or allow back-to-back
            
        # Wait a cycle to ensure last char is stored
        await RisingEdge(dut.clk)
        
        # 2. Set Total and Start
        if not is_value_defined(dut.total.value):
             # This happens if dut.total is not in the port list, but prompt says it is.
             # If dut.total is an internal signal, we can't set it directly.
             # The prompt says "Inputs: input [7:0] total".
             pass
             
        # The Prompt I will write defines 'total' as an input.
        # However, I must check if the Prompt I write actually matches the testbench.
        # If I write 'total' as input, but the user runs with a design that doesn't have it, it fails.
        # The Prompt is the specification. It MUST be accurate.
        
        dut.total.value = total
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for Done
        max_cycles = 100
        done_found = False
        
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value):
                if dut.done.value == 1:
                    done_found = True
                    break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
            
        # 4. Check Result
        if not is_value_defined(dut.mangoes.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
            
        result = int(dut.mangoes.value)
        
        # Handle negative results: 
        # The prompt says "return the number of the mango fruits".
        # Python function returns negative if total < (apple+orange). 
        # Example: "2 apples and 3 oranges", 5 -> 5 - 2 - 3 = 0. (Matches test case)
        # Example: "100 apples and 1 oranges", 5 -> 5 - 100 - 1 = -96.
        # The test cases provided don't explicitly check for negative results, but we should handle them.
        # Usually in unsigned hardware, this wraps around or saturates.
        # Let's check the expected values in the test cases:
        # Case 5: "2 apples and 3 oranges", 5 -> Expected 0. (Correct)
        # Let's assume the design outputs 0 on negative results (saturation) OR standard 2's complement.
        # The test case expects 0 for (5 - 5). If we have (5 - 6) = -1.
        # Python int(0xFF) = 255. Signed int(0xFF) = -1.
        
        # The test cases provided:
        # 5 apples and 6 oranges, 19 -> 8
        # 2 apples and 3 oranges, 5 -> 0
        # 
        # I will implement a check that converts the result to signed 8-bit if expected is negative.
        # BUT the test cases don't include negative expected values. 
        # The last test case: 1 apple, 100 orange, 120 total -> 19.
        
        # Let's assume the design does standard subtraction (unsigned). 
        # If result < 0, hardware wraps to 255.. etc.
        # To be robust, I will convert to signed for comparison if expected is negative.
        # But wait, the test cases provided by the user don't have negative expected values.
        # I will stick to the exact expected values provided.
        # However, "2 apples and 3 oranges", 5 -> 0. This works.
        
        if result != expected:
            # Special handling if we expect negative but hardware gave 2's complement
            if result > 127 and expected < 0:
                if result + expected == 256:
                    dut._log.warning(f"Test {i+1}: Result {result} (signed {result-256}) matches expected {expected}")
                    passed += 1
                    continue
                    
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {i+1} Passed")
        passed += 1
        
        # Small delay between tests
        await Timer(50, units='ns')
        
    dut._log.info(f"\nSummary: {passed}/{total_tests} tests passed")
    if passed == total_tests:
        raise TestSuccess("All tests passed!")
    else:
        raise TestFailure(f"{total_tests - passed} tests failed")
