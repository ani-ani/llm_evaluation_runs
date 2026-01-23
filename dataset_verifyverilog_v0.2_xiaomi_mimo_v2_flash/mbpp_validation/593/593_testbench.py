import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_ip_remove_leading_zeros(dut):
    """Test IP address leading zero removal"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.ip_in.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    def str_to_ascii(s, width=15):
        """Convert string to ASCII bytes in hex format"""
        ascii_bytes = [ord(c) for c in s]
        # Pad to 15 characters with nulls (0x00)
        while len(ascii_bytes) < width:
            ascii_bytes.append(0x00)
        # Pack into single hex value (big-endian)
        result = 0
        for i, b in enumerate(ascii_bytes):
            result |= (b << ((width - 1 - i) * 8))
        return result
    
    def ascii_to_str(hex_val, width=15):
        """Convert hex value back to string"""
        s = ""
        for i in range(width):
            byte_val = (hex_val >> ((width - 1 - i) * 8)) & 0xFF
            if byte_val == 0:
                break
            s += chr(byte_val)
        return s
    
    test_cases = [
        ("216.08.094.196", "216.8.94.196"),
        ("12.01.024      ", "12.1.24       "),  # padded with spaces
        ("216.08.094.0196", "216.8.94.196"),
        ("0.0.0.0        ", "0.0.0.0        "),  # all zeros - keep one zero
        ("192.168.1.1    ", "192.168.1.1    "),  # no leading zeros
        ("001.002.003.004", "1.2.3.4        "),  # all have leading zeros
        ("007.070.700.000", "7.70.700.0     "),  # mixed cases
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_ip, expected_ip) in enumerate(test_cases):
        print(f"
Test {i+1}: Input='{input_ip.strip()}' Expected='{expected_ip.strip()}'")
        
        # Prepare input
        input_hex = str_to_ascii(input_ip)
        dut.ip_in.value = input_hex
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 50 cycles + safety)
        timeout = 60
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Read output
        output_hex = int(dut.ip_out.value)
        output_str = ascii_to_str(output_hex)
        expected_str = expected_ip.strip()
        output_str_clean = output_str.strip()
        
        print(f"  Output: '{output_str_clean}'")
        
        # Check result
        if output_str_clean == expected_str:
            passed += 1
            print(f"  ✓ PASS")
        else:
            print(f"  ✗ FAIL - Expected '{expected_str}', got '{output_str_clean}'")
        
        # Small delay between tests
        await Timer(50, units='ns')
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} of {total} tests passed"
