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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_new_tuple(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (list_str_id_0, list_str_id_1, input_str_id, expected_result, desc)
    # Using 8-bit string IDs
    test_cases = [
        (0x57, 0x45, 0x42, [0x57, 0x45, 0x42], "WEB is best"),  # 'W','E','B' IDs
        (0x57, 0x65, 0x44, [0x57, 0x65, 0x44], "We are Devs"),   # 'W','e','D'
        (0x50, 0x49, 0x57, [0x50, 0x49, 0x57], "Part is Wrong") # 'P','I','W'
    ]
    
    passed = failed = 0
    
    for i, (str0, str1, str_in, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            dut.list_str_id_0.value = clamp_to_width(str0, 8)
            dut.list_str_id_1.value = clamp_to_width(str1, 8)
            dut.input_str_id.value = clamp_to_width(str_in, 8)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Verify results
            if not is_value_defined(dut.result_0.value) or \
               not is_value_defined(dut.result_1.value) or \
               not is_value_defined(dut.result_2.value):
                raise TestFailure("Result outputs undefined")
            
            result = [
                int(dut.result_0.value),
                int(dut.result_1.value),
                int(dut.result_2.value)
            ]
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Check result length
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len undefined")
            if int(dut.result_len.value) != 3:
                raise TestFailure(f"Expected len=3, got {int(dut.result_len.value)}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed+failed}")