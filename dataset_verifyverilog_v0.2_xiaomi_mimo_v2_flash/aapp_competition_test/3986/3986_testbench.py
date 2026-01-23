import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_generator(dut):
    """Test the string generator module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, k, expected_string, description)
    test_cases = [
        (7, 4, "ababacd", "Example 1: n=7, k=4"),
        (4, 7, "-1", "Example 2: k > n (impossible)"),
        (10, 5, "abababacde", "n=10, k=5"),
        (47, 2, "abababababababababababababababababababababababa", "n=47, k=2 (large alternating)"),
        (1, 1, "a", "Base case: n=1, k=1"),
        (2, 2, "ab", "Base case: n=2, k=2"),
        (10, 7, "ababacdefg", "n=10, k=7"),
        (26, 26, "abcdefghijklmnopqrstuvwxyz", "n=26, k=26 (full alphabet)"),
        (2, 1, "-1", "Impossible: k=1, n>1"),
        (1, 2, "-1", "Impossible: k>n"),
        (128, 26, "ababababababababababababababababababababababababababababababababababababababababababababababababababababcdefghijklmnopqrstuvwxyz", "Max size: n=128, k=26")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, expected_str, desc in test_cases:
        # Prepare inputs
        dut.n.value = n_val
        dut.k.value = k_val
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (valid high or error high)
        # We need to wait a reasonable amount of time based on n (max 128)
        # 128 cycles + overhead should be safe. Let's wait 200 cycles max.
        timeout = 200
        found = False
        
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.valid.value == 1 or dut.error.value == 1:
                found = True
                break
        
        if not found:
            raise TestFailure(f"Timeout for {desc}")
        
        # Check result
        if expected_str == "-1":
            if dut.error.value != 1:
                raise TestFailure(f"{desc}: Expected error=1, got {dut.error.value}")
            print(f"PASS: {desc}")
            passed += 1
        else:
            if dut.error.value == 1:
                raise TestFailure(f"{desc}: Unexpected error")
            
            # Decode result
            # dut.result is a 1023:0 vector. We need to extract bytes.
            # Pack into a bytearray
            res_bytes = []
            length = len(expected_str)
            
            # Check length
            if dut.length_out.value != length:
                 raise TestFailure(f"{desc}: Length mismatch. Expected {length}, got {dut.length_out.value}")
            
            # Read chars
            for i in range(length):
                # Bits are indexed [7:0] for char 0 (LSB), [15:8] for char 1, etc.
                # Or if standard packed: char 0 is [7:0], char 1 is [15:8]...
                # Depending on definition. Usually Verilog packed arrays are MSB first.
                # If result [1023:0] and char 0 is at index 0, it might be bits [7:0].
                # Let's assume standard packed: char 0 -> [7:0], char 1 -> [15:8]...
                byte = (dut.result.value >> (i * 8)) & 0xFF
                res_bytes.append(chr(byte))
            
            generated = "".join(res_bytes)
            
            if generated != expected_str:
                raise TestFailure(f"{desc}: Mismatch.
Expected: {expected_str}
Got:      {generated}")
            
            print(f"PASS: {desc} -> {generated}")
            passed += 1
            
    print(f"
Summary: {passed}/{total} tests passed")
