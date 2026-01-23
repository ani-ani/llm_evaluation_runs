import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_arrow_reconstruction(dut):
    """Test the arrow reconstruction module."""
    # Detect clk
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have clk signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Helper to compute expected B
    def compute_expected(N, K):
        # Compute gcd
        a, b = N, K
        while b:
            a, b = b, a % b
        gcd_val = a
        if gcd_val != 1:
            return None
        # Compute modular inverse
        for s in range(1, N):
            if (s * K) % N == 1:
                break
        else:
            return None  # Should not happen if gcd=1
        # Build B (1-indexed)
        B = []
        for i in range(N):
            B.append(((i + s) % N) + 1)
        return B
    
    # Test cases: (N, K, description)
    test_cases = [
        (3, 2, "N=3, K=2"),
        (4, 2, "N=4, K=2 (impossible)"),
        (5, 3, "N=5, K=3"),
        (7, 4, "N=7, K=4"),
        (8, 6, "N=8, K=6 (impossible)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Set inputs
        dut.N.value = N
        dut.K.value = K
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        impossible = int(dut.impossible.value) if is_value_defined(dut.impossible.value) else 0
        
        expected = compute_expected(N, K)
        
        if expected is None:
            # Expect impossible
            if impossible != 1:
                dut._log.error(f"  FAIL: Expected impossible, but got possible")
                failed += 1
            else:
                dut._log.info(f"  PASS: Correctly detected impossible")
                passed += 1
        else:
            # Expect possible
            if impossible == 1:
                dut._log.error(f"  FAIL: Expected possible, but got impossible")
                failed += 1
            else:
                # Read b_0..b_7
                b_vals = []
                for idx in range(8):
                    port_name = f'b_{idx}'
                    if has_signal(dut, port_name):
                        val = getattr(dut, port_name).value
                        if is_value_defined(val):
                            b_vals.append(int(val))
                        else:
                            b_vals.append(None)
                    else:
                        b_vals.append(None)
                
                # Compare only first N
                b_vals = b_vals[:N]
                
                if None in b_vals:
                    dut._log.error(f"  FAIL: Some B outputs undefined")
                    failed += 1
                elif b_vals == expected:
                    dut._log.info(f"  PASS: B = {b_vals}")
                    passed += 1
                else:
                    dut._log.error(f"  FAIL: Expected {expected}, got {b_vals}")
                    failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")