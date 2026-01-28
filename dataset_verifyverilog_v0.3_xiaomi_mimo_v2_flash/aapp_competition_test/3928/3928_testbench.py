import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Configuration
CLK_PERIOD_NS = 10

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_string_compression(dut):
    """Test the string compression module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down to max 8 characters)
    test_cases = [
        # n, a, b, string, expected output
        (3, 3, 1, "aba", 7),
        (4, 1, 1, "abcd", 4),
        (4, 10, 1, "aaaa", 12),
        (1, 3102, 3554, "b", 3102),
        (3, 3310, 2775, "ndn", 9395),
        (7, 3519, 1996, "gzgngzg", 14549),
        (3, 3, 1, "aba", 7),  # Duplicate to verify
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, a, b, s, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, a={a}, b={b}, s='{s}', expected={expected}")
        
        # Pad string to 8 characters
        s_padded = s + '\0' * (8 - len(s))
        
        # Convert string to ASCII values
        ascii_vals = [ord(c) if c != '\0' else 0 for c in s_padded]
        
        # Set inputs
        dut.s0.value = ascii_vals[0]
        dut.s1.value = ascii_vals[1]
        dut.s2.value = ascii_vals[2]
        dut.s3.value = ascii_vals[3]
        dut.s4.value = ascii_vals[4]
        dut.s5.value = ascii_vals[5]
        dut.s6.value = ascii_vals[6]
        dut.s7.value = ascii_vals[7]
        dut.a.value = a
        dut.b.value = b
        dut.n.value = n
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await RisingEdge(dut.clk)  # Combinational result ready in next cycle
        
        # Read result
        if is_value_defined(dut.min_cost.value):
            result = int(dut.min_cost.value)
            if result == expected:
                cocotb.log.info(f"  PASS: result = {result}")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
                failed += 1
        else:
            cocotb.log.error(f"  FAIL: min_cost is undefined")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")