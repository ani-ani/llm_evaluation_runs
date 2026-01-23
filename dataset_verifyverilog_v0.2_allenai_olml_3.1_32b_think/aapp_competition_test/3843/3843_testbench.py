import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import itertools

def get_digits_base7(val, length):
    if val == 0:
        return [0] * length
    digits = []
    temp = val
    while temp > 0:
        digits.append(temp % 7)
        temp //= 7
    while len(digits) < length:
        digits.append(0)
    return digits[::-1]

def get_required_length(val):
    if val == 0:
        return 1
    length = 0
    temp = val
    while temp > 0:
        temp //= 7
        length += 1
    return length

def is_valid_pair(h, m, max_h, max_m):
    if h >= max_h or m >= max_m:
        return False
    h_digits = get_digits_base7(h, get_required_length(max_h-1))
    m_digits = get_digits_base7(m, get_required_length(max_m-1))
    all_digits = h_digits + m_digits
    return len(set(all_digits)) == len(all_digits)

@cocotb.test()
async def test_robber_watches(dut):
    """Test robber watches logic"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (2, 3, 4),   # Example 1
        (8, 2, 5),   # Example 2
        (1, 1, 0),   # Small 1
        (8, 8, 0),   # Overlap (8 is 11_7, needs 2 digits, 1,1 overlap)
        (10, 5, 1),  # 10 is 13_7 (len 2), 5 is 5_7 (len 1). Valid: 0:5, 1:5, 3:5 (distinct digits). Wait, 0:5 -> {0,5}, 1:5->{1,5}, 3:5->{3,5}. 3 valid.
    ]
    
    for n_val, m_val, expected in test_cases:
        dut.n.value = n_val
        dut.m.value = m_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 2000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 2000:
            raise TestFailure(f"Timeout for n={n_val}, m={m_val}")
            
        actual = int(dut.result.value)
        print(f"n={n_val}, m={m_val}, Expected={expected}, Actual={actual}")
        if actual != expected:
            raise TestFailure(f"Result mismatch: got {actual}, expected {expected}")
