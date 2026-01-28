import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
MOD = 1000000007
PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]
MAX_PRIMES = 11

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def factorize(x, primes):
    """Return exponents of primes for number x."""
    exp = [0] * len(primes)
    for i, p in enumerate(primes):
        while x % p == 0:
            exp[i] += 1
            x //= p
        if x == 1:
            break
    # Any remaining factor is ignored (assumed to be 1)
    return exp

def binomial(e, n):
    """Compute C(e + n - 1, n - 1) mod MOD."""
    if n == 1:
        return 1
    # Compute numerator product (e+1)*(e+2)*...*(e+n-1)
    num = 1
    for i in range(1, n):
        num = (num * (e + i)) % MOD
    # Multiply by inverse factorial of n-1
    inv_fact = {0:1, 1:1, 2:500000004, 3:166666668, 4:41666667, 5:808333337, 6:201388893, 7:35791429}
    den = inv_fact[n-1]
    return (num * den) % MOD

def compute_expected(n, a_list):
    """Compute expected result using the formula."""
    if n == 1:
        return 1
    # Factor all numbers
    total_exp = [0] * MAX_PRIMES
    for a in a_list:
        exp = factorize(a, PRIMES)
        for i in range(MAX_PRIMES):
            total_exp[i] += exp[i]
    # Compute product of binomials
    result = 1
    for e in total_exp:
        if e > 0:
            result = (result * binomial(e, n)) % MOD
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_decomposition_counter(dut):
    # Detect interface
    has_exp_ports = all(has_signal(dut, f'exp{i}') for i in range(MAX_PRIMES))
    if not has_exp_ports:
        dut._log.error("Missing exp0..exp10 ports")
        raise TestFailure("Missing expected ports")

    # Start clock
    clk_period_ns = 10
    cocotb.start_soon(Clock(dut.clk, clk_period_ns, units='ns').start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        (1, [15]),
        (3, [1, 1, 2]),
        (2, [5, 7]),
        (2, [5, 10]),
        (3, [1, 30, 1]),
        (2, [1000000000, 1000000000]),
        (1, [1]),
        (3, [1, 1, 1]),
        (2, [1, 2]),
        (2, [1, 6]),
        (3, [8, 10, 8]),
        (5, [14, 67, 15, 28, 21]),
        (8, [836, 13, 77, 218, 743, 530, 404, 741]),
        (10, [6295, 3400, 4042, 2769, 3673, 264, 5932, 4977, 1776, 5637]),
        (23, [77, 12, 25, 7, 44, 75, 80, 92, 49, 77, 56, 93, 59, 45, 45, 39, 86, 83, 99, 91, 4, 70, 83]),
        (1, [111546435]),
        (7, [111546435, 58642669, 600662303, 167375713, 371700317, 33984931, 89809099]),
        (19, [371700317, 12112039, 167375713, 7262011, 21093827, 89809099, 600662303, 18181979, 9363547, 30857731, 58642669, 111546435, 645328247, 5605027, 38706809, 14457349, 25456133, 44227723, 33984931]),
        (1, [536870912]),
        (2, [536870912, 387420489]),
        (10, [214358881, 536870912, 815730721, 387420489, 893871739, 244140625, 282475249, 594823321, 148035889, 410338673]),
        (5, [387420489, 536870912, 536870912, 536870912, 387420489]),
        (5, [387420489, 244140625, 387420489, 387420489, 1]),
        (10, [2097152, 67108864, 65536, 262144, 262144, 131072, 8388608, 536870912, 65536, 2097152]),
        (10, [237254761, 1, 817430153, 1, 1, 1, 1, 1, 90679621, 1]),
        (20, [16777216, 1048576, 524288, 8192, 8192, 524288, 2097152, 8388608, 1048576, 67108864, 16777216, 1048576, 4096, 8388608, 134217728, 67108864, 1048576, 536870912, 67108864, 67108864]),
        (50, [675, 25000, 2025, 50, 450, 31250, 3750, 225, 1350, 250, 72, 187500, 12000, 281250, 187500, 30000, 45000, 90000, 90, 1200, 9000, 56250, 5760, 270000, 3125, 3796875, 2250, 101250, 40, 2500, 175781250, 1250000, 45000, 2250, 3000, 31250, 46875, 135000, 421875000, 36000, 360, 140625000, 13500, 1406250, 1125, 250, 75000, 62500, 150, 6]),
        (2, [999983, 999983]),
        (3, [1, 1, 39989])
    ]

    passed = 0
    failed = 0

    for idx, (n, a_list) in enumerate(test_cases):
        dut._log.info(f"\nTest {idx+1}: n={n}, a={a_list}")

        # Compute expected result
        expected = compute_expected(n, a_list)

        # Factorize to get exponents
        total_exp = [0] * MAX_PRIMES
        for a in a_list:
            exp = factorize(a, PRIMES)
            for i in range(MAX_PRIMES):
                total_exp[i] += exp[i]

        # Set inputs
        dut.n.value = n
        for i in range(MAX_PRIMES):
            port_name = f'exp{i}'
            getattr(dut, port_name).value = total_exp[i]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done with timeout
        cycles = 0
        max_cycles = 50000
        while cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout after {max_cycles} cycles")

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined")
        result = int(dut.result.value)

        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected={expected}, got={result}")
            failed += 1

    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")