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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_binary_string(val):
    return f"0b{val:b}"

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rounded_avg(dut):
    # Clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Test cases: (n, m, expected_result, expected_error)
    test_cases = [
        (1, 5, 3, False),      # avg=3
        (7, 13, 10, False),    # avg=10
        (7, 5, 0, True),       # n > m
        (5, 5, 5, False),      # single element
        (964, 977, 970, False), # large but valid (clamped to 255, but test within 8-bit)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, exp_result, exp_error) in enumerate(test_cases):
        # Clamp inputs to 8-bit range
        n_clamped = clamp_to_width(n_val, 8)
        m_clamped = clamp_to_width(m_val, 8)
        
        cocotb.log.info(f"Test {i+1}: n={n_clamped}, m={m_clamped}")
        
        try:
            # Set inputs
            dut.n.value = n_clamped
            dut.m.value = m_clamped
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for valid or error
            timeout_cycles = 512
            for cycle in range(timeout_cycles):
                await RisingEdge(dut.clk)
                valid = is_value_defined(dut.valid.value) and int(dut.valid.value) == 1
                error = is_value_defined(dut.error.value) and int(dut.error.value) == 1
                
                if valid or error:
                    # Read results
                    result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
                    
                    if exp_error:
                        if not error:
                            raise TestFailure(f"Expected error=1, got error={int(dut.error.value)}")
                        if result != 0:
                            raise TestFailure(f"For error case, expected result=0, got {result}")
                    else:
                        if not valid:
                            raise TestFailure(f"Expected valid=1, got valid={int(dut.valid.value)}")
                        if error:
                            raise TestFailure(f"Expected error=0, got error=1")
                        
                        # Calculate expected result for clamped values
                        actual_n = min(n_val, 255)
                        actual_m = min(m_val, 255)
                        if actual_n > actual_m:
                            # Should have been error
                            if not error:
                                raise TestFailure(f"Input n>m after clamping, expected error")
                        else:
                            expected = (actual_n + actual_m) // 2
                            if result != expected:
                                raise TestFailure(f"Expected {expected}, got {result}")
                    
                    passed += 1
                    break
            else:
                raise TestFailure(f"Timeout after {timeout_cycles} cycles")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")