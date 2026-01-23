import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def phi_python(n):
    if n == 1:
        return 1
    result = n
    p = 2
    temp = n
    while p * p <= temp:
        if temp % p == 0:
            while temp % p == 0:
                temp //= p
            result -= result // p
        p += 1
    if temp > 1:
        result -= result // temp
    return result

def compute_f_k(n, k):
    if n == 1:
        return 1
    steps = (k + 1) // 2
    current = n
    for _ in range(steps):
        if current == 1:
            break
        current = phi_python(current)
    return current

@cocotb.test()
async def test_eurus_solver(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
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
    
    # Test cases: (n, k, expected)
    # Scaled test cases to fit n <= 1000, k <= 100
    test_cases = [
        (7, 1, 6),
        (10, 2, 4),
        (15, 3, 4),  # phi(phi(phi(15))) = phi(8) = 4
        (100, 5, 2),
        (1, 100, 1),
        (512, 10, 1),
        (999, 20, 1),
        (17, 1, 16),
        (2, 1, 1),
        (3, 10, 1)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, expected in test_cases:
        # Inputs
        dut.n.value = n_val
        dut.k.value = k_val
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 500 # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"PASS: n={n_val}, k={k_val}, expected={expected}, got={actual}")
        else:
            print(f"FAIL: n={n_val}, k={k_val}, expected={expected}, got={actual}")
            
        # Small delay between tests
        await Timer(100, units='ns')

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
