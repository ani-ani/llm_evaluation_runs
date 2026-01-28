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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

# Constraints
DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 2048

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_packing(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
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
    
    # Test cases: (N, Expected Empty)
    test_cases = [
        (47, 1),
        (523, 2),
        (100000000, 15), # Scale test (N=1e8)
        (2147483647, 1),  # Max signed 32-bit
        (1, 0)
    ]
    
    passed = 0
    failed = 0
    
    for n_input, exp_empty in test_cases:
        n_scaled = n_input  # Use input directly for this scaled test
        
        cocotb.log.info(f"Testing N={n_scaled}, expecting empty={exp_empty}")
        
        try:
            # Set inputs
            dut.N.value = clamp_to_width(n_scaled, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                cycles = 0
                while True:
                    if cycles > MAX_CYCLES:
                        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    await RisingEdge(dut.clk)
                    cycles += 1
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != exp_empty:
                raise TestFailure(f"Expected {exp_empty}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: N={n_scaled} -> empty={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
