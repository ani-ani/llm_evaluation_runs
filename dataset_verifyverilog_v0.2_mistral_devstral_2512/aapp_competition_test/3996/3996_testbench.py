import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

MOD = 1000000007
PHI = 1000000006
INV3 = 333333336

def modular_pow(base, exponent, modulus):
    if modulus == 1:
        return 0
    result = 1
    base = base % modulus
    while exponent > 0:
        if (exponent % 2) == 1:
            result = (result * base) % modulus
        exponent = exponent >> 1
        base = (base * base) % modulus
    return result

def get_expected(arr):
    # Calculate n = product(arr) mod PHI
    n_mod_phi = 1
    is_even = False
    for x in arr:
        n_mod_phi = (n_mod_phi * (x % PHI)) % PHI
        if x % 2 == 0:
            is_even = True
    
    # Calculate 2^(n-1) mod MOD
    # Note: handle n=0 case (product=0), though inputs are >= 1
    if n_mod_phi == 0:
        # Product is multiple of PHI. 2^(k*PHI - 1) = 2^(PHI-1) * (2^PHI)^k = 2^(PHI-1)
        x = modular_pow(2, PHI - 1, MOD)
    else:
        x = modular_pow(2, n_mod_phi - 1, MOD)
    
    # Calculate numerator
    if is_even:
        num = (x + 1) * INV3 % MOD
    else:
        num = (x - 1 + MOD) * INV3 % MOD
    
    return num, x

@cocotb.test()
async def test_cups_and_key(dut):
    """Test the Cups and Key solver module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.last_in.value = 0
    dut.a_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: inputs, expected (num, den)
    test_cases = [
        ([2], get_expected([2])),
        ([1, 1, 1], get_expected([1, 1, 1])),
        ([983155795040951739], get_expected([983155795040951739])),
        ([467131402341701583, 956277077729692725], get_expected([467131402341701583, 956277077729692725])),
        ([1], get_expected([1])),
        ([1000000000000000000], get_expected([1000000000000000000])),
    ]

    passed = 0
    total = len(test_cases)

    for arr, (exp_x, exp_y) in test_cases:
        # Feed inputs
        for i, val in enumerate(arr):
            dut.valid_in.value = 1
            dut.a_in.value = val
            if i == len(arr) - 1:
                dut.last_in.value = 1
            else:
                dut.last_in.value = 0
            
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            # Wait for done or keep processing inputs
            # In this design, inputs can be back-to-back if we are in PROCESS_INPUT state.
            # If we need to wait for calculation after last_in, we break the feed loop.
            if i == len(arr) - 1:
                break
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 1000:
            raise TestFailure(f"Timeout waiting for done on input {arr}")
            
        # Check results
        res_x = int(dut.result_x.value)
        res_y = int(dut.result_y.value)
        
        if res_x == exp_x and res_y == exp_y:
            passed += 1
            dut._log.info(f"PASS: Input {arr} -> {res_x}/{res_y}")
        else:
            dut._log.error(f"FAIL: Input {arr} -> Got {res_x}/{res_y}, Expected {exp_x}/{exp_y}")
            raise TestFailure(f"Mismatch on input {arr}")
        
        # Reset for next test (optional if module is designed to handle new sequence, 
        # but safe to reset here to clear internal flags)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    print(f"
SUMMARY: {passed}/{total} tests passed")