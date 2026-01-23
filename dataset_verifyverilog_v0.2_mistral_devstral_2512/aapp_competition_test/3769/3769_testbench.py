import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to calculate the expected value based on the problem logic
def calculate_expected(p, k):
    MOD = 10**9 + 7
    if k == 0:
        # p^(p-1)
        return pow(p, p - 1, MOD)
    elif k == 1:
        # p^p
        return pow(p, p, MOD)
    else:
        # Find multiplicative order of k modulo p
        o = 1
        curr = k
        while curr != 1:
            curr = (curr * k) % p
            o += 1
        # p^((p-1)//o)
        return pow(p, (p - 1) // o, MOD)

@cocotb.test()
async def test_func_count(dut):
    """Test the func_count module with various inputs."""
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_in.value = 0
    dut.k_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define test cases (p, k) - scaled down to fit hardware limits (p < 1024)
    # We pick representative cases from the Python test cases but scaled down.
    # Original pairs: (3,2), (5,4), (7,2), (5,0), (5,3), (7,1)
    test_cases = [
        (3, 2, 3),
        (5, 4, 25),
        (7, 2, 49),
        (5, 0, 625),  # 5^4 = 625
        (5, 3, 5),
        (7, 1, 823543), # 7^7 is large, might overflow 16-bit result, but fits in 32-bit register
        (11, 10, 11),
        (13, 5, 169),
        (13, 4, 13)
    ]

    passed = 0
    total = len(test_cases)

    for p, k, expected_python in test_cases:
        # Note: The expected_python value from the problem context is modulo 10^9+7.
        # The Verilog module is expected to output the result modulo M (where M is 10^9+7 in concept, 
        # but hardware likely computes the raw value or a scaled modulus). 
        # For this benchmark, we check the raw power result if it fits, or just the logic.
        # Actually, the Python code outputs modulo 10^9+7. 
        # Let's calculate the exact expected value using the logic provided in the Python snippets.
        
        expected = calculate_expected(p, k)
        
        print(f"Testing p={p}, k={k}, Expected={expected}")

        # Apply inputs
        # Convert to Q16.16 format (integer part in upper 16 bits)
        dut.p_in.value = p << 16
        dut.k_in.value = k << 16
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1

        if timeout >= 500:
            raise TestFailure(f"Timeout for p={p}, k={k}")

        # Read result
        # Result is in Q16.16, so we shift right by 16 to get the integer part
        result_int = int(dut.result.value) >> 16

        # We need to account for the modulo 10^9+7 if the number is huge (like 7^7).
        # However, the problem statement asks for the number of functions.
        # If the Verilog implementation handles the exponentiation directly, it might overflow 32-bit.
        # Given the constraints of the module (32-bit result reg), it likely computes the value modulo something 
        # or the hardware is intended for smaller numbers.
        # Let's check against the raw value if < 2^32, else check against expected % (2^32) or similar.
        # Actually, the Python snippets compute modulo 10^9+7.
        # If the Verilog is strictly combinational logic for small numbers, we verify the integer result.
        # If the number is huge (like 823543), the hardware module likely needs to implement modulo arithmetic.
        # Assuming the prompt implies the module computes the result correctly for the scaled inputs.
        
        # Let's verify against the expected value. If expected is larger than what fits in 32-bit result (unsigned),
        # we might have issues. 823543 is smaller than 2^32.
        # 7^7 = 823543. This fits.
        # 5^4 = 625. This fits.
        # 11^11 is huge (2.8e11). This also fits in 32-bit unsigned (max ~4e9). 
        # Actually 11^11 is 2.85e11 which is > 2^32 (4.29e9). 
        # So for k=1, p=11, we expect 11^11 % 10^9+7 = 116668611... 
        # But wait, the Python examples show 11 1 -> 311668616.
        # The problem says "modulo 10^9 + 7".
        # The Verilog module result register is 32-bit. It cannot store 11^11 directly.
        # It MUST be doing modular exponentiation modulo 10^9+7 (or just modulo something if we simplify).
        # Given the prompt asks for a Verilog module, and the Python code computes modulo 10^9+7,
        # the Verilog should probably compute the result modulo 10^9+7.
        # However, implementing 10^9+7 in a simple module is tricky if we want exact parity.
        # Let's assume the module is tested for correct logic flow and small inputs where raw values fit.
        # OR, we accept that the result is modulo 10^9+7.
        # Let's check: 11^11 mod 10^9+7 = 311668616.
        # If the Verilog implements this modulo operation, it should match.
        
        # If we assume the module is for small p (e.g. < 100), then 11^11 is too big.
        # Let's focus on the small test cases provided: (3,2), (5,4), (7,2), (5,0), (5,3), (7,1).
        # (7,1): 7^7 = 823543. This fits in 32-bit. 
        # (5,0): 5^4 = 625. Fits.
        # (3,2): 3^1 = 3. Fits.
        # (5,4): 5^1 = 5? No. Wait. Python example: 5 4 -> 25.
        # Logic: k=4, p=5. Order of 4 mod 5? 4^1=4, 4^2=16=1 mod 5. Order is 2.
        # Exponent = (p-1)/order = 4/2 = 2. Result = 5^2 = 25. Fits.
        # (7,2): p=7, k=2. Order of 2 mod 7? 2^3=8=1 mod 7. Order=3. (7-1)/3=2. 7^2=49. Fits.
        # (5,3): p=5, k=3. Order of 3 mod 5? 3^1=3, 3^2=9=4, 3^3=12=2, 3^4=6=1. Order=4. (5-1)/4=1. 5^1=5. Fits.
        
        # Conclusion: For these specific test cases, the raw integer result fits in 32 bits.
        # We will verify the integer part of the result against the expected raw value.
        
        if result_int != expected:
             # Check if it's a modulo issue (unlikely for these small cases if implemented correctly)
             # But if we added modulo logic, we would check `result_int % 1000000007`.
             # Let's just check exact match for the small cases.
             raise TestFailure(f"Mismatch: p={p}, k={k}. Expected {expected}, got {result_int}")
        
        passed += 1
        await RisingEdge(dut.clk)

    print(f"
Summary: {passed}/{total} tests passed.")

    if passed == total:
        print("ALL TESTS PASSED")
