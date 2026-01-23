import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Helper to determine primality for Python side checks
def is_prime_py(n):
    if n <= 1: return False
    if n <= 3: return True
    if n % 2 == 0 or n % 3 == 0: return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0: return False
        i += 6
    return True

def is_happy(n, M):
    return (n <= M) or is_prime_py(n)

def find_solution_py(K, L, M):
    # Search bounded range as per adaptation
    for x in range(1, 2001):
        count = 0
        for k in range(K):
            if is_happy(x + k, M):
                count += 1
        if count == L:
            return x
    return -1

@cocotb.test()
async def test_mirko_solver(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.K.value = 0
    dut.L.value = 0
    dut.M.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases from Python problem (scaled inputs if necessary, but here we use the provided constraints)
    test_cases = [
        (1, 1, 1), # Expected 1
        (2, 0, 2), # Expected 8 (range [8,9]: 8<=2? No. 9<=2? No. Primes? 9 No, 8 No. 0 happy.)
        (3, 1, 1), # Expected 4 (range [4,6]: 4(No), 5(Prime/Yes), 6(No). Count=1.)
        (4, 1, 1), # Expected 6 (range [6,9]: 6,7,8,9. Happy: 7. Count=1.)
        (5, 2, 3), # Expected 4 (range [4,8]: 4,5,6,7,8. Happy: 5(Prime), 7(Prime). Count=2.)
    ]

    for K, L, M in test_cases:
        print(f"
Testing K={K}, L={L}, M={M}")
        
        # Send inputs
        dut.K.value = K
        dut.L.value = L
        dut.M.value = M
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 10000: # Safety break
                print("Timeout!")
                assert False, "Timeout waiting for done"

        actual = int(dut.result.value)
        expected = find_solution_py(K, L, M)
        
        print(f"  Expected: {expected}, Got: {actual}")
        assert actual == expected, f"Mismatch for K={K}, L={L}, M={M}"

    print("
All tests passed!")