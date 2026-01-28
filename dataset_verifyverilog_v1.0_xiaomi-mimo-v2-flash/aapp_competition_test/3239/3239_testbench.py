import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Fixed-point helpers for Q16.16

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Testbench

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_pokemon_cost(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - wait for stability
        await Timer(100, units='ns')
    
    # Test cases: (N, P_float, expected_cost_float)
    test_cases = [
        (50, 0.125, 16.339203308),
        (201, 1.0, 5.000000000),
        (7, 0.0, 35.000000000),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, P_float, expected_cost) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, P={P_float}, expected={expected_cost}")
        
        try:
            # Convert inputs
            N_in = clamp_to_width(N, 16)
            P_in_scaled = int(P_float * 1000)  # P*1000 as integer
            P_in = clamp_to_width(P_in_scaled, 10)
            
            # Set inputs
            if has_signal(dut, 'N_in'):
                dut.N_in.value = N_in
            elif has_signal(dut, 'N'):
                dut.N.value = N_in
            else:
                # Try individual bits
                for b in range(16):
                    sig_name = f'N_in_{b}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = (N_in >> b) & 1
            
            if has_signal(dut, 'P_in'):
                dut.P_in.value = P_in
            elif has_signal(dut, 'P'):
                dut.P.value = P_in
            else:
                for b in range(10):
                    sig_name = f'P_in_{b}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = (P_in >> b) & 1
            
            # Start calculation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    # Assume computation starts on valid inputs
                    await RisingEdge(dut.clk)
                
                # Wait for done
                max_cycles = 200
                for cycle in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    # Check valid signal if available
                    if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                        break
                else:
                    raise TestFailure(f"Did not complete within {max_cycles} cycles")
            else:
                await Timer(500, units='ns')
            
            # Read result
            result_signal = None
            if has_signal(dut, 'result'):
                result_signal = dut.result
            elif has_signal(dut, 'output'):
                result_signal = dut.output
            else:
                # Try to find any 32-bit output
                for name in ['result', 'cost', 'output', 'total']:
                    if has_signal(dut, name):
                        result_signal = getattr(dut, name)
                        break
            
            if result_signal is None:
                raise TestFailure("Cannot find result signal")
            
            if not is_value_defined(result_signal.value):
                raise TestFailure("Result signal undefined")
            
            result_q16_16 = int(result_signal.value)
            result_float = fixed_to_float(result_q16_16)
            
            # Allow tolerance for floating-point calculations
            tolerance = 0.001  # 1e-3 for Q16.16 approximation
            abs_error = abs(result_float - expected_cost)
            rel_error = abs_error / max(expected_cost, 1e-9)
            
            if abs_error > tolerance and rel_error > tolerance:
                raise TestFailure(
                    f"Expected {expected_cost:.9f}, got {result_float:.9f} "
                    f"(abs_error={abs_error:.9f}, rel_error={rel_error:.9f})"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_float:.9f}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests for sequential designs
        if is_seq and i < len(test_cases) - 1:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Final summary
    cocotb.log.info(f"Results: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")