import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

# Fixed-point constants
FRAC_BITS = 16
INT_BITS = 16
Q16_16_SCALE = 1 << FRAC_BITS

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point integer"""
    return int(f * Q16_16_SCALE)

def q16_16_to_float(v):
    """Convert Q16.16 fixed-point integer to float"""
    return v / Q16_16_SCALE

# Precomputed probabilities for N=2..14 (exact values)
PROB_TABLE = {
    2: 1.0,
    3: 1.0,
    4: 0.962962962963,
    5: 0.938082191781,
    6: 0.926269650294,
    7: 0.922888601550,
    8: 0.922816757141,
    9: 0.923676028382,
    10: 0.924911973784,
    11: 0.926364503017,
    12: 0.927951428495,
    13: 0.929627997843,
    14: 0.931371149025
}

def get_probability(n):
    """Get probability for given N"""
    if n < 2 or n > 140:
        raise ValueError(f"N={n} out of range")
    
    if n <= 14:
        return PROB_TABLE[n]
    else:
        # Approximation for large N: P ≈ 1 - (N-1)/N^(N-1)
        # For large N, N^(N-1) is huge, probability approaches 1
        if n > 20:
            return 1.0 - 1e-10  # Very close to 1
        # For N=15..20, use a simple approximation
        return 1.0 - ((n-1) / (n ** (n-1)))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def compute_probability(dut, n):
    """Start computation and return result"""
    # Set input
    dut.n_in.value = clamp_to_width(n, 8)
    
    # Start pulse
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.probability.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.probability.value)
    
    # Check valid signal if exists
    if has_signal(dut, 'valid'):
        if not is_value_defined(dut.valid.value):
            raise TestFailure("Valid signal undefined")
        if int(dut.valid.value) != 1:
            raise TestFailure("Valid signal not high")
    
    return result

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_probability_computation(dut):
    """Test probability computation for various N values"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: no clock/reset needed
        await Timer(10, units='ns')
    
    # Test cases: (N, expected_probability, description)
    test_cases = [
        (2, 1.0, "N=2: Must be connected"),
        (3, 1.0, "N=3: Must be connected"),
        (4, 0.962962962963, "N=4: Known value"),
        (5, 0.938082191781, "N=5: Known value"),
        (6, 0.926269650294, "N=6: Known value"),
        (7, 0.922888601550, "N=7: Known value"),
        (8, 0.922816757141, "N=8: Known value"),
        (9, 0.923676028382, "N=9: Known value"),
        (10, 0.924911973784, "N=10: Known value"),
        (11, 0.926364503017, "N=11: Known value"),
        (12, 0.927951428495, "N=12: Known value"),
        (13, 0.929627997843, "N=13: Known value"),
        (14, 0.931371149025, "N=14: Known value"),
        (15, 0.933153215241, "N=15: Approximation"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected_prob, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {desc} (N={n})")
        
        try:
            if is_seq:
                result_q16 = await compute_probability(dut, n)
            else:
                # Combinational: set input and read output
                dut.n_in.value = clamp_to_width(n, 8)
                await Timer(100, units='ns')
                if not is_value_defined(dut.probability.value):
                    raise TestFailure("Result undefined")
                result_q16 = int(dut.probability.value)
            
            # Convert result to float
            result_prob = q16_16_to_float(result_q16)
            
            # Calculate error
            error = abs(result_prob - expected_prob)
            
            # For sequential test, also check done/valid signals
            if is_seq and has_signal(dut, 'done'):
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not high")
            
            # For N≤14, require high precision (error < 1e-7)
            # For N>14, allow more error (error < 1e-3)
            if n <= 14:
                max_error = 1e-7
            else:
                max_error = 1e-3
            
            if error > max_error:
                raise TestFailure(
                    f"Error {error:.2e} > {max_error:.2e}. "
                    f"Expected: {expected_prob:.12f}, Got: {result_prob:.12f}, "
                    f"Result Q16.16: 0x{result_q16:08X}"
                )
            
            cocotb.log.info(f"  Result: {result_prob:.12f} (Q16.16: 0x{result_q16:08X}), "
                          f"Expected: {expected_prob:.12f}, Error: {error:.2e}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Test boundary cases
    cocotb.log.info("Testing boundary cases...")
    
    # Test N=140 (upper bound)
    try:
        if is_seq:
            result_q16 = await compute_probability(dut, 140)
        else:
            dut.n_in.value = 140
            await Timer(100, units='ns')
            result_q16 = int(dut.probability.value)
        
        result_prob = q16_16_to_float(result_q16)
        
        # For N=140, probability should be extremely close to 1.0
        if result_prob < 0.9999:
            raise TestFailure(f"N=140 probability too low: {result_prob}")
        
        cocotb.log.info(f"N=140: {result_prob:.12f} (should be ≈1.0)")
        passed += 1
        
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test reset functionality"""
    
    if not has_signal(dut, 'clk'):
        cocotb.log.info("Skipping reset test: module is combinational")
        return
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    # Check reset state
    if has_signal(dut, 'done'):
        if not is_value_defined(dut.done.value):
            raise TestFailure("Done signal undefined during reset")
        if int(dut.done.value) != 0:
            raise TestFailure(f"Done should be 0 during reset, got {int(dut.done.value)}")
    
    if has_signal(dut, 'valid'):
        if not is_value_defined(dut.valid.value):
            raise TestFailure("Valid signal undefined during reset")
        if int(dut.valid.value) != 0:
            raise TestFailure(f"Valid should be 0 during reset, got {int(dut.valid.value)}")
    
    # Check probability output is 0
    if is_value_defined(dut.probability.value):
        if int(dut.probability.value) != 0:
            raise TestFailure(f"Probability should be 0 during reset, got {int(dut.probability.value)}")
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # After reset, module should be ready
    cocotb.log.info("Reset test passed")

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_fixed_point_conversion(dut):
    """Test fixed-point conversion and value representation"""
    
    # Test Q16.16 conversion
    test_values = [
        (1.0, 0x00010000),  # 1.0 in Q16.16
        (0.5, 0x00008000),  # 0.5 in Q16.16
        (0.962962962963, 0x0F7B0F5B),  # Expected for N=4
        (0.0, 0x00000000),
        (0.75, 0x0000C000),  # 3/4 in Q16.16
    ]
    
    for expected_float, expected_q16 in test_values:
        calculated_q16 = float_to_q16_16(expected_float)
        # Allow small rounding error (±1)
        if abs(calculated_q16 - expected_q16) > 1:
            raise TestFailure(
                f"Q16.16 conversion error: {expected_float} -> "
                f"Expected 0x{expected_q16:08X}, Got 0x{calculated_q16:08X}"
            )
        
        calculated_float = q16_16_to_float(calculated_q16)
        error = abs(calculated_float - expected_float)
        if error > 1e-6:
            raise TestFailure(
                f"Q16.16 reverse conversion error: {calculated_q16:#x} -> "
                f"Expected {expected_float}, Got {calculated_float}, Error: {error}"
            )
    
    cocotb.log.info("Fixed-point conversion tests passed")

if __name__ == "__main__":
    # This would normally be run via cocotb
    print("This testbench should be run with cocotb")
    print("Example: make TESTCASE=test_probability_computation")
