import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_decimal_to_binary(dut):
    """Test decimal to binary conversion with db markers"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.decimal.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_binary_string_without_db)
    # We'll check the binary conversion part (positions 2-9)
    # For 0: "00000000" -> ASCII '0's (0x30)
    # For 15: "00001111" -> ASCII bits
    # For 32: "00100000" -> ASCII bits  
    # For 103: "01100111" -> ASCII bits
    
    test_cases = [
        (0, "00000000"),
        (15, "00001111"),
        (32, "00100000"),
        (103, "01100111"),
    ]
    
    for i, (decimal_val, expected_bits) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: input={decimal_val}")
        
        # Set input and start
        dut.decimal.value = decimal_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 10 cycles timeout)
        done_found = False
        for cycle in range(10):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: done signal not asserted after 10 cycles")
        
        # Check result is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result is undefined (X/Z)")
        
        # Extract the result
        result_val = int(dut.result.value)
        
        # The result is 96-bit string in little-endian format
        # Check the 'db' prefix (positions 11:10, which are bytes 11 and 10)
        # Actually, in little-endian: result[7:0] = char 0
        # So char 0 = result[7:0], char 1 = result[15:8], etc.
        
        # Extract each byte and verify
        # Expected format: 'd','b',8 binary chars,'d','b'
        # Positions: 0='d'(0x64), 1='b'(0x62), 2-9=binary chars, 10='d', 11='b'
        
        def get_byte(result, pos):
            """Extract byte at position pos (0-11) from little-endian result"""
            shift = pos * 8
            mask = 0xFF << shift
            return (result & mask) >> shift
        
        # Check prefix
        byte0 = get_byte(result_val, 0)  # Should be 'd' = 0x64
        byte1 = get_byte(result_val, 1)  # Should be 'b' = 0x62
        
        if byte0 != 0x64:
            raise TestFailure(f"Test {i+1}: Position 0 expected 0x64 ('d'), got 0x{byte0:02X}")
        if byte1 != 0x62:
            raise TestFailure(f"Test {i+1}: Position 1 expected 0x62 ('b'), got 0x{byte1:02X}")
        
        # Check suffix
        byte10 = get_byte(result_val, 10)  # Should be 'd' = 0x64
        byte11 = get_byte(result_val, 11)  # Should be 'b' = 0x62
        
        if byte10 != 0x64:
            raise TestFailure(f"Test {i+1}: Position 10 expected 0x64 ('d'), got 0x{byte10:02X}")
        if byte11 != 0x62:
            raise TestFailure(f"Test {i+1}: Position 11 expected 0x62 ('b'), got 0x{byte11:02X}")
        
        # Check binary characters (positions 2-9)
        for j in range(8):
            expected_char = expected_bits[j]
            expected_ascii = 0x30 if expected_char == '0' else 0x31
            actual_byte = get_byte(result_val, 2 + j)
            
            if actual_byte != expected_ascii:
                raise TestFailure(
                    f"Test {i+1}: Binary position {j} expected {expected_char} (0x{expected_ascii:02X}), "
                    f"got 0x{actual_byte:02X}"
                )
        
        dut._log.info(f"  Test {i+1} passed: db{expected_bits}db")
    
    dut._log.info(f"\nSummary: {len(test_cases)}/{len(test_cases)} tests passed")
