import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_slon_solver(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases: (a, b, P, M, expected_x)
    # Linear equation: (a*x + b) % M = P
    # Example 1: 5+3+x => 1*x + 8 = P (mod M)
    # Sample 1: 9 = x+8 (mod 10) => x=1
    # Sample 2: 0 = x+23 (mod 5) => 23%5=3, 0=x+3 => x=2
    # Sample 3: 3*(x+(x+4)*5) = 3*(6x+20) = 18x+60 = x+5 (mod 7) since 18%7=4, 60%7=4. 4x+4=1 => 4x=4 => x=1
    
    test_cases = [
        (1, 8, 9, 10, 1),
        (1, 23, 0, 5, 2),
        (18, 60, 1, 7, 1),
        (2, 0, 4, 6, 2),  # 2x = 4 => x=2
        (3, 1, 0, 4, 1),  # 3x+1=0 mod 4 => 3x=3 => x=1
    ]

    passed = 0
    failed = 0

    for i, (a_val, b_val, p_val, m_val, exp_x) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_val}, b={b_val}, P={p_val}, M={m_val}, Exp={exp_x}")
        
        try:
            # Set inputs
            dut.a.value = clamp_to_width(a_val, 20)
            dut.b.value = clamp_to_width(b_val, 20)
            dut.P.value = clamp_to_width(p_val, 20)
            dut.M.value = clamp_to_width(m_val, 20)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 200
            found_done = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure(f"Timeout waiting for done")
            
            # Check result
            if not is_value_defined(dut.x_out.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.x_out.value)
            if result != exp_x:
                raise TestFailure(f"Expected {exp_x}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed")