import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_strange_sort(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Helper to pack array into bits
    def pack_input(arr, elem_bits=8, max_len=16):
        packed = 0
        for i, val in enumerate(arr):
            if i >= max_len: break
            packed |= (clamp_to_width(val, elem_bits) << (i * elem_bits))
        return packed

    # Test cases (scaled to 8-bit for HDL)
    test_cases = [
        ([1, 2, 3, 4], 4, [1, 4, 2, 3]),
        ([5, 6, 7, 8, 9], 5, [5, 9, 6, 8, 7]),
        ([5, 5, 5, 5], 4, [5, 5, 5, 5]),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, [1, 8, 2, 7, 3, 6, 4, 5]),
        ([111, 111], 2, [111, 111]),  # 111111 scaled down
        ([-5, 0, 5], 3, [-5, 5, 0])   # Negative handling
    ]

    passed = 0
    failed = 0

    for i, (inp_arr, length, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {inp_arr}, Expected {expected}")
        
        try:
            # Prepare inputs
            packed = pack_input(inp_arr)
            dut.arr_in.value = packed
            dut.arr_valid.value = 1
            dut.len.value = length
            
            # Start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            dut.arr_valid.value = 0
            
            # Collect results
            results = []
            timeout = 0
            while len(results) < length:
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 200:
                    raise TestFailure(f"Timeout collecting results for case {i+1}")
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    # Extract result (assuming it streams out 1 element per cycle on 'result' port)
                    # The spec says result is 16-bit, let's assume the lower 8 bits is the current element
                    if has_signal(dut, 'result'):
                        val = int(dut.result.value) & 0xFF
                        results.append(val)
                elif is_value_defined(dut.done.value) and int(dut.done.value) == 0 and has_signal(dut, 'result'):
                     # If valid immediately, grab it
                     pass
            
            # Verify (only check first few if array is huge, but here max is 8)
            if results != expected:
                raise TestFailure(f"Expected {expected}, got {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Case {i}: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")