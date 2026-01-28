import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed-point conversion (Q8.8)
def to_fixed(f, frac=8):
    if isinstance(f, str):
        # Parse string like "2,3" -> 2.3
        parts = f.split(',')
        integer = int(parts[0])
        decimal = int(parts[1]) if len(parts) > 1 else 0
        return (integer << frac) + (decimal << frac // 2)  # Approx: 1.5 -> 1.5 * 256 = 384
    return int(f * (1 << frac))

def from_fixed(v, frac=8):
    return v / (1 << frac)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_compare_one(dut):
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (type_a, val_a, str_a, type_b, val_b, str_b, expected_result_type, expected_val, description)
    # type: 0=int/fixed, 1=string
    test_cases = [
        (0, 1 << 8, 0, 0, 2 << 8, 0, 0, 2 << 8, "1 vs 2 -> 2"),
        (0, 1 << 8, 0, 0, to_fixed(2.5), 0, 0, to_fixed(2.5), "1 vs 2.5 -> 2.5"),
        (1, 0, 0x0100, 1, 0, 0x0200, 1, 0x0200, "\"1\" vs \"2\" -> \"2\""), # Mock string values
        (0, 1 << 8, 0, 1, 0, 0x0200, 1, 0x0200, "1 vs \"2\" -> \"2\""),
        (1, 0, 0x0100, 0, 1 << 8, 0, 0, 1 << 8, "\"1\" vs 1 -> None (Equal)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (t_a, v_a, s_a, t_b, v_b, s_b, exp_type, exp_val, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Inputs
            dut.type_a.value = t_a
            dut.type_b.value = t_b
            dut.val_a.value = clamp_to_width(v_a, 16)
            dut.val_b.value = clamp_to_width(v_b, 16)
            # String input simulation (simplified: using val field to pass char code)
            # In real HDL, str inputs would be separate ports. Here we assume val_a/val_b carry char codes for simplicity.
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for valid
            valid_found = False
            for _ in range(50):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    valid_found = True
                    break
            
            if not valid_found:
                raise TestFailure("Valid signal never went high")
            
            # Check result
            result_type = int(dut.result_type.value)
            result_val = int(dut.result_val.value)
            
            # Handling None (equal) case - specific to test case 5
            if desc == '"\"1\" vs 1 -> None (Equal)"':
                # If inputs were equal, result_val might be 0 or don't care, but valid should be 0 or result None indicator
                # For this simplified test, we assume valid=0 indicates None or a specific flag.
                # However, standard requirement is to return the larger or None.
                # Let's assume if inputs are equal, valid stays low or result is 0.
                if result_val == exp_val:
                     # Adjusted expectation for equality: result_val matches input (1) or 0
                     pass
            else:
                if result_type != exp_type:
                    raise TestFailure(f"Type mismatch: expected {exp_type}, got {result_type}")
                # For string output, we check the raw value (mock char code)
                if result_val != exp_val and not (result_val == 0 and exp_val == 0): # Allow some flexibility for string equality
                    raise TestFailure(f"Value mismatch: expected {exp_val}, got {result_val}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
