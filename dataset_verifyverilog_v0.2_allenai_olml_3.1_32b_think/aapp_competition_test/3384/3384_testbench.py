import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def is_handsome(num):
    """Check if a number is handsome (consecutive digits have different parity)"""
    if num < 10:
        return True
    s = str(num)
    for i in range(len(s)-1):
        d1 = int(s[i])
        d2 = int(s[i+1])
        if (d1 % 2) == (d2 % 2):
            return False
    return True

def find_closest_handsome(N):
    """Find closest handsome numbers to N"""
    if is_handsome(N):
        return []
    
    lower = None
    upper = None
    
    # Search lower
    for i in range(1, 1000):
        candidate = N - i
        if candidate < 0:
            break
        if is_handsome(candidate):
            lower = candidate
            break
    
    # Search upper
    for i in range(1, 1000):
        candidate = N + i
        if is_handsome(candidate):
            upper = candidate
            break
    
    if lower is not None and upper is not None:
        dist_lower = N - lower
        dist_upper = upper - N
        if dist_lower < dist_upper:
            return [lower]
        elif dist_upper < dist_lower:
            return [upper]
        else:
            return [lower, upper]
    elif lower is not None:
        return [lower]
    else:
        return [upper]

def int_to_bcd(num, digits=8):
    """Convert integer to packed BCD format (4 bits per digit)"""
    bcd = 0
    s = str(num)
    # Pad to 8 digits
    s = s.zfill(digits)
    for i in range(digits):
        digit = int(s[i])
        bcd |= (digit << (4 * (digits - 1 - i)))
    return bcd

def bcd_to_int(bcd, digits=8):
    """Convert packed BCD to integer"""
    result = 0
    for i in range(digits):
        digit = (bcd >> (4 * (digits - 1 - i))) & 0xF
        result = result * 10 + digit
    return result

@cocotb.test()
async def test_closest_handsome(dut):
    """Test closest handsome number finder"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_number.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (13, [12, 14]),
        (5801001, [5810101]),
        (1, []),  # Already handsome
        (22, [21, 23]),  # Both equally close
        (99, [98, 101]),  # Different distances
        (10, [12]),  # Only upper
        (100, [101]),  # Only upper (99 is handsome)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_val, expected in test_cases:
        # Skip if already handsome
        if is_handsome(input_val):
            dut._log.info(f"Skipping {input_val} (already handsome)")
            total -= 1
            continue
        
        dut._log.info(f"Testing N={input_val}")
        
        # Load input
        bcd_input = int_to_bcd(input_val)
        dut.input_number.value = bcd_input
        await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            dut._log.error(f"Timeout for N={input_val}")
            continue
        
        # Read results
        found_lower = bool(dut.found_lower.value)
        found_upper = bool(dut.found_upper.value)
        result_lower = bcd_to_int(int(dut.result_lower.value)) if found_lower else None
        result_upper = bcd_to_int(int(dut.result_upper.value)) if found_upper else None
        
        # Check results
        actual = []
        if found_lower:
            actual.append(result_lower)
        if found_upper:
            actual.append(result_upper)
        
        # Sort to match expected order
        actual.sort()
        
        dut._log.info(f"Expected: {expected}, Got: {actual}")
        
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Mismatch for N={input_val}: expected {expected}, got {actual}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
