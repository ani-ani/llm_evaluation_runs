import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_horse_chase(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        pass
    
    # Test cases (scaled to fit within constraints: L<=15)
    test_cases = [
        # (L, A, B, P) -> expected result
        (5, 4, 3, 2, 3),  # Original: scaled input (5,4,3,2) -> 3
        (5, 4, 2, 3, 3),  # Original: scaled input (5,4,2,3) -> 3
    ]
    
    passed = 0
    failed = 0
    
    for i, (L, A, B, P, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: L={L}, A={A}, B={B}, P={P}")
        
        try:
            # Map inputs to module ports
            if has_signal(dut, 'L'):
                dut.L.value = clamp_to_width(L, 5)
            else:
                # Input not connected, assume it's inside (testbench will simulate)
                pass
            
            if has_signal(dut, 'A'):
                dut.A.value = clamp_to_width(A, 5)
            
            if has_signal(dut, 'B'):
                dut.B.value = clamp_to_width(B, 5)
            
            if has_signal(dut, 'P'):
                dut.P.value = clamp_to_width(P, 5)
            
            # Start calculation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if has_signal(dut, 'result'):
                    result_val = int(dut.result.value)
                    if result_val != expected:
                        raise TestFailure(f"Expected {expected}, got {result_val}")
                else:
                    raise TestFailure("Result signal not found")
            else:
                # Combinational: wait for stability
                await Timer(100, units='ns')
                if has_signal(dut, 'result'):
                    result_val = int(dut.result.value)
                    if result_val != expected:
                        raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
