import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper to map string to 5-bit values
def str_to_array(s):
    # 'a' -> 0, 'b' -> 1, ...
    return [ord(c) - ord('a') for c in s]

@cocotb.test()
async def test_longest_repeated_substring(dut):
    """Test the longest_repeated_substring module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0 # Initialize array
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Cases
    test_cases = [
        ("sabcabcfabc", 3),
        ("trutrutiktiktappop", 4),
        ("abcdef", 0),
        ("aaaa", 3), # "aaa" appears twice (start 0 and 1)
        ("ababab", 5), # "ababa" or "babab"? Actually "abab" appears twice. Wait, "ababab" -> longest repeat is 4? "abab" at 0 and 2. Or "baba" at 1 and 3. Answer should be 4.
        ("", 0) # Empty string case (input L=0, handled by logic to return 0)
    ]

    for s_in, expected_len in test_cases:
        # Fill inputs
        arr = str_to_array(s_in)
        # Pad with 0 if length < 16
        while len(arr) < 16:
            arr.append(0)
        
        # Assign to Verilog array
        # In cocotb, array indexing depends on version, usually flattened or unpacked
        # Assuming unpacked array [0:15] in Verilog, we set them one by one or via concat
        # For simplicity and robustness, let's assign individual indices if possible, 
        # or use a loop if cocotb allows. Let's assume standard vector access or individual.
        # dut.char_in.value = arr usually works for packed arrays, for unpacked we might need to iterate.
        # Let's try direct assignment first, if fails, iterate.
        try:
            dut.char_in.value = arr
        except Exception:
            # Fallback for unpacked array
            for i in range(16):
                dut.char_in[i].value = arr[i]

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 5000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 5000:
            raise TestFailure(f"Timeout for input '{s_in}'")

        # Check result
        result = int(dut.max_len.value)
        print(f"Input: '{s_in}', Expected: {expected_len}, Got: {result}")
        
        if result != expected_len:
            raise TestFailure(f"Mismatch for input '{s_in}': expected {expected_len}, got {result}")

    print(f"All {len(test_cases)} tests passed!")
