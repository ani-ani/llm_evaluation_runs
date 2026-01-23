import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

MOD = 1000000007

def modular_exponentiation(base, exp, mod):
    result = 1
    base = base % mod
    while exp > 0:
        if exp % 2 == 1:
            result = (result * base) % mod
        base = (base * base) % mod
        exp //= 2
    return result

def calculate_expected(n, k):
    if k == 1:
        term1 = 1
    else:
        term1 = modular_exponentiation(k, k - 1, MOD)
    
    rem = n - k
    if rem == 0:
        term2 = 1
    else:
        term2 = modular_exponentiation(rem, rem, MOD)
        
    return (term1 * term2) % MOD

@cocotb.test()
async def test_penguin_walkways(dut):
    """Test the penguin_walkways module with various inputs."""
    
    # Setup clock
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
    
    # Test cases: (n, k)
    # We must respect hardware limits: n <= 65535, k <= 8
    test_cases = [
        (5, 2),
        (7, 4),
        (8, 5),
        (8, 1),
        (10, 7),
        (12, 8),
        (50, 2),
        (100, 8),
        (1000, 8),
        (999, 7),
        (1, 1),
        (2, 1),
        (2, 2),
        (3, 3)
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"Starting tests for {total} cases...")
    
    for n_val, k_val in test_cases:
        dut.n.value = n_val
        dut.k.value = k_val
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 600:
                print(f"Timeout for n={n_val}, k={k_val}")
                break
        
        # Check result
        if dut.done.value == 1:
            hw_result = int(dut.result.value)
            expected = calculate_expected(n_val, k_val)
            
            if hw_result == expected:
                print(f"PASS: n={n_val}, k={k_val}, Result={hw_result}")
                passed += 1
            else:
                print(f"FAIL: n={n_val}, k={k_val}, Expected={expected}, Got={hw_result}")
        else:
            print(f"FAIL: n={n_val}, k={k_val}, Module did not finish")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
