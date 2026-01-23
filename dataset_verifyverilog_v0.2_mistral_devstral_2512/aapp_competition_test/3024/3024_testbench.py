import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_palindrome_partition(dut):
    """Test maximal palindrome partitioning on various strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_data.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (string, expected_k)
    test_cases = [
        ('652526', 4),
        ('12121131221', 7),  # Will be truncated to 8 chars
        ('123456789', 1),    # Truncated to 8 chars
        ('132594414896459441321', 9),  # Truncated to 8 chars
        ('1', 1),
        ('11', 2),
        ('121', 3),
        ('1221', 4),
        ('123123', 6),
        ('1234321', 7),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for string_input, expected_k in test_cases:
        # Truncate to 8 characters for testing
        test_string = string_input[:8]
        str_len = len(test_string)
        
        # Convert string to bytes (ASCII digits)
        str_bytes = [ord(c) for c in test_string]
        
        # Pack into Verilog vector (8 chars × 8 bits each)
        # str_data[7:0] = first char, str_data[15:8] = second char, etc.
        packed_data = 0
        for i, byte in enumerate(str_bytes):
            packed_data |= (byte << (i * 8))
        
        # Load inputs
        dut.str_data.value = packed_data
        dut.str_len.value = str_len
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout for string '{test_string}'")
        
        # Read result
        result_k = int(dut.max_k.value)
        
        if result_k == expected_k:
            passed += 1
            print(f"✓ PASS: '{test_string}' -> k={result_k} (expected {expected_k})")
        else:
            print(f"✗ FAIL: '{test_string}' -> k={result_k} (expected {expected_k})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"{total - passed} tests failed")
