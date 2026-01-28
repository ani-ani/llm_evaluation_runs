import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_median_trapezium(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (base1, base2, height, expected_result, description)
    # Note: Third case expects 7.5 in float, but we use integer division
    test_cases = [
        (15, 25, 35, 20, "Test 1: 15+25=40, /2=20"),
        (10, 20, 30, 15, "Test 2: 10+20=30, /2=15"),
        (6, 9, 4, 7, "Test 3: 6+9=15, /2=7 (integer division)"),
        (0, 0, 0, 0, "Test 4: Edge case zeros"),
        (255, 255, 255, 255, "Test 5: Max values"),
        (100, 150, 50, 125, "Test 6: 100+150=250, /2=125")
    ]
    
    passed = 0
    failed = 0
    
    for i, (base1, base2, height, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            dut.base1.value = clamp_to_width(base1, 8)
            dut.base2.value = clamp_to_width(base2, 8)
            dut.height.value = clamp_to_width(height, 8)
            
            if is_seq:
                # Trigger calculation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} (expected {expected}) - PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal tests: {len(test_cases)}, Passed: {passed}, Failed: {failed}")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")