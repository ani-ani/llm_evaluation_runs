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

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Testbench
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_big_sum(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_sum)
    test_cases = [
        ([1, 2, 3] + [0]*13, 4, "Small positive"),
        ([-1, 2, 3, 4] + [0]*12, 3, "Mixed signs"),
        ([2, 3, 6] + [0]*13, 8, "Small sum"),
        ([-10, 10, -5, 5, 0] + [0]*11, 0, "Symmetric"),
        ([127, -128, 0] + [0]*13, -1, "Extreme values")
    ]
    
    passed = 0
    failed = 0
    
    for inp, expected, desc in test_cases:
        cocotb.log.info(f"Testing: {desc}")
        
        # Fill array (arr is 16x8 bits)
        # Check if arr is a bus or indexed
        if has_signal(dut, 'arr') and hasattr(dut.arr, '__len__'):
            # It's likely an array of signals
            for i in range(16):
                val = from_signed(inp[i], 8) if inp[i] < 0 else inp[i]
                dut.arr[i].value = clamp_to_width(val, 8)
        else:
            # Assume single bus for arr if indexed access fails
            # But specification implies arr[0:7], so let's try indexing
             raise TestFailure("Array access signal 'arr' not found as expected")

        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut)
            
            # Check result
            res_val = int(dut.result.value)
            # Convert from 2's complement if negative
            if res_val >= 128: # 16-bit signed check (assuming 16 bits, 2^15=32768)
                # Actually result is 16 bit. Max pos is 32767.
                # If HDL sim returns a LogicArray, we need to interpret it
                # Let's assume the simulator returns integer value
                pass
            
            # Handle 16-bit signed result
            if res_val >= 32768:
                res_val = res_val - 65536
                
            if res_val != expected:
                raise TestFailure(f"Expected {expected}, got {res_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
