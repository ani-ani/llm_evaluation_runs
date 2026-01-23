import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def float_to_fixed(f, shift=16):
    return int(f * (1 << shift))

def fixed_to_float(fixed, shift=16):
    return fixed / (1 << shift)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bus_time_calculator(dut):
    """Test bus time calculator with binary search."""
    
    # Detect sequential module
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n, l, v1, v2, k, expected_time)
    # Values are scaled for Q16.16 fixed-point
    test_cases = [
        (5, 10.0, 1.0, 2.0, 5, 5.0),
        (3, 6.0, 1.0, 2.0, 1, 4.7142857143),
        (8, 100.0, 10.0, 20.0, 3, 15.0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, l, v1, v2, k, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, l={l}, v1={v1}, v2={v2}, k={k}")
        
        try:
            # Convert to Q16.16 fixed-point
            n_fp = float_to_fixed(n)
            l_fp = float_to_fixed(l)
            v1_fp = float_to_fixed(v1)
            v2_fp = float_to_fixed(v2)
            k_fp = float_to_fixed(k)
            
            # Assign inputs
            dut.n.value = n_fp
            dut.l.value = l_fp
            dut.v1.value = v1_fp
            dut.v2.value = v2_fp
            dut.k.value = k_fp
            
            if is_sequential:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                for cycle in range(1000):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure("Timeout waiting for done")
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.time.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fp = int(dut.time.value)
            result = fixed_to_float(result_fp)
            
            # Verify with tolerance
            tolerance = max(0.01, abs(expected) * 0.01)
            if abs(result - expected) > tolerance:
                raise TestFailure(f"Expected {expected:.6f}, got {result:.6f}")
            
            dut._log.info(f"  PASS: time = {result:.6f}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")