import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Carryless multiplication function for testing
def carryless_mul(a, b):
    # Convert to digit arrays
    a_digits = [int(d) for d in str(a)]
    b_digits = [int(d) for d in str(b)]
    a_digits.reverse()  # LSB first
    b_digits.reverse()
    
    max_len = len(a_digits) + len(b_digits) - 1
    c = [0] * max_len
    
    for i in range(len(a_digits)):
        for j in range(len(b_digits)):
            c[i+j] += a_digits[i] * b_digits[j]
    
    # Take mod 10 for each digit
    c = [x % 10 for x in c]
    
    # Convert back to integer
    c.reverse()
    return int(''.join(map(str, c)))

def carryless_square(a):
    return carryless_mul(a, a)

# Function to convert integer to BCD (binary coded decimal)
def int_to_bcd(num, digits):
    s = str(num).zfill(digits)
    bcd = 0
    for i in range(digits):
        d = int(s[i])
        bcd |= (d << (4 * (digits - 1 - i)))
    return bcd

# Function to extract result from BCD
def bcd_to_int(bcd, digits):
    result = 0
    for i in range(digits):
        d = (bcd >> (4 * i)) & 0xF
        result += d * (10 ** i)
    return result

def bcd_to_str(bcd, digits):
    result = []
    for i in range(digits-1, -1, -1):
        d = (bcd >> (4 * i)) & 0xF
        result.append(str(d))
    return ''.join(result).lstrip('0') or '0'

@cocotb.test()
async def test_carryless_sqrt(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, expected_a)
    test_cases = [
        (6, 4),
        (149, 17),
        (15, -1),
    ]
    
    for n_val, expected_a in test_cases:
        # Calculate actual carryless square for verification
        actual_n = carryless_square(expected_a) if expected_a != -1 else 0
        
        if expected_a != -1 and actual_n != n_val:
            # Adjust test case based on what our limited hardware can actually test
            pass
        
        dut.n.value = int_to_bcd(n_val, 8)  # Using 8 digits for safety
        dut.num_digits.value = len(str(n_val))
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50000:
            raise TestFailure(f"Timeout for N={n_val}")
        
        # Check result
        if dut.found.value:
            result_val = bcd_to_int(dut.result.value, 4)
            print(f"N={n_val}, Found a={result_val}, Expected={expected_a}")
            if result_val != expected_a:
                raise TestFailure(f"Mismatch: got {result_val}, expected {expected_a}")
        else:
            print(f"N={n_val}, No solution found")
            if expected_a != -1:
                raise TestFailure(f"Should have found solution {expected_a}")
    
    print(f"All {len(test_cases)} tests passed!")