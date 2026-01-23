import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

# Helper to map n, k to expected character based on the problem logic
# This mimics the logic we expect in hardware
def get_expected_char(n, k):
    f0 = "What are you doing at the end of the world? Are you busy? Will you save us?"
    prefix = 'What are you doing while sending "'
    mid = '"? Are you busy? Will you send "'
    suffix = '"?'
    
    # Calculate lengths
    len_f0 = len(f0)
    len_prefix = len(prefix)
    len_mid = len(mid)
    len_suffix = len(suffix)
    
    # Cap lengths at 10^18 (simulated as a large number)
    # f_len[i] = min(10^18, 2 * f_len[i-1] + 68)
    f_len = [0] * 60
    f_len[0] = len_f0
    for i in range(1, 60):
        val = 2 * f_len[i-1] + 68
        if val > 10**18:
            f_len[i] = 10**18
        else:
            f_len[i] = val

    # Iterative descent
    while True:
        if n == 0:
            if k <= len_f0:
                return f0[k-1]
            else:
                return '.'
        
        # Check prefix
        if k <= len_prefix:
            return prefix[k-1]
        k -= len_prefix
        
        # Check first recursive part
        # If n-1 is large, f_len[n-1] is effectively infinite
        if n-1 >= 55:
             # For large n, the recursive parts are huge, so k is always inside them unless it falls in the strings
             # Since we passed prefix, k must be in the first recursive part
             n -= 1
             continue
             
        if k <= f_len[n-1]:
            n -= 1
            continue
        k -= f_len[n-1]
        
        # Check mid
        if k <= len_mid:
            return mid[k-1]
        k -= len_mid
        
        # Check second recursive part
        if n-1 >= 55:
            n -= 1
            continue
            
        if k <= f_len[n-1]:
            n -= 1
            continue
        k -= f_len[n-1]
        
        # Check suffix
        if k <= len_suffix:
            return suffix[k-1]
        
        return '.'

@cocotb.test()
async def test_nephren_solver(dut):
    # Create a clock with 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    dut.k_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (n, k)
    test_cases = [
        (1, 1),      # First char of f1
        (1, 2),      # Second char of f1
        (1, 111111111111), # Out of bounds -> .
        (0, 69),     # Out of bounds -> .
        (1, 194),    # Mid of f1
        (1, 139),    # Mid of f1
        (0, 47),     # Inside f0
        (1, 66),     # Inside f1
        (4, 1825),   # Larger case
        (2, 474),    # Larger case
        (50, 80501843339247582), # Large n, large k (should handle 64-bit k)
        (999, 1000000000000000000) # Very large n
    ]

    passed = 0
    total = len(test_cases)

    for n, k in test_cases:
        # Prepare inputs
        dut.n_in.value = n
        dut.k_in.value = k
        dut.start.value = 1
        
        # Wait for start to be sampled
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Get result
        hw_result = dut.char_out.value.integer
        if hw_result == 0:
            hw_char = '.'
        else:
            hw_char = chr(hw_result)
        
        # Expected result
        expected_char = get_expected_char(n, k)
        
        # Check
        if hw_char == expected_char:
            dut._log.info(f"PASS: n={n}, k={k} -> '{hw_char}'")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n}, k={k}. Expected '{expected_char}', got '{hw_char}'")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total
