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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Expected star number calculation
def expected_star_num(n):
    return 6 * n * (n - 1) + 1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_star_number(dut):
    # Setup clock and reset
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verify reset state
    if has_signal(dut, 'result'):
        if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
            cocotb.log.warning(f"Result after reset: {int(dut.result.value)}")
    
    test_cases = [
        (3, 37, "n=3"),
        (4, 73, "n=4"),
        (5, 121, "n=5"),
        (0, 1, "n=0"),
        (1, 1, "n=1"),
        (10, 541, "n=10")
    ]
    
    passed = 0
    failed = 0
    
    for n, exp, desc in test_cases:
        cocotb.log.info(f"Test case: {desc}, n={n}, expected={exp}")
        try:
            # Set n input
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 5)
            
            # Assert start pulse
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done with timeout
            max_cycles = 100
            done_found = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        done_found = True
                        break
            
            if not done_found:
                raise TestFailure(f"Done signal not asserted within {max_cycles} cycles")
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            result = int(dut.result.value)
            
            # Check result (clamp to 16 bits if needed)
            clamped_exp = clamp_to_width(exp, 16)
            if result != clamped_exp:
                raise TestFailure(f"Expected {clamped_exp}, got {result}")
            
            # Small delay before next test
            await Timer(50, units='ns')
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    # Additional test: verify state machine resets properly
    cocotb.log.info("Testing reset mid-calculation...")
    try:
        # Start a calculation
        if has_signal(dut, 'n'):
            dut.n.value = 10
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait 2 cycles, then assert reset
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Verify reset
        if has_signal(dut, 'result') and is_value_defined(dut.result.value):
            if int(dut.result.value) != 0:
                raise TestFailure(f"Result after reset should be 0, got {int(dut.result.value)}")
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) != 0:
                raise TestFailure(f"Done after reset should be 0, got {int(dut.done.value)}")
        
        passed += 1
        cocotb.log.info("PASS: Reset mid-calculation")
        
    except TestFailure as e:
        cocotb.log.error(f"FAIL: Reset test - {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")