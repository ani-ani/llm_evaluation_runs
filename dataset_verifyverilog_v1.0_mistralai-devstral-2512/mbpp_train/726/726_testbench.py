import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_multiply_elements(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(3): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases (N=4 input, N-1=3 output)
    test_cases = [
        ([0x01, 0x05, 0x07, 0x08], [5, 35, 56], "1,5,7,8"),
        ([0x02, 0x04, 0x05, 0x06], [8, 20, 30], "2,4,5,6"),
        ([0x0C, 0x0D, 0x0E, 0x09], [156, 182, 126], "12,13,14,9"),
        ([0x0C, 0x0D, 0x0E, 0x0F], [156, 182, 189], "12,13,14,15"),
        ([0x00, 0x00, 0x00, 0x00], [0, 0, 0], "zeros"),
        ([0xFF, 0x01, 0x02, 0x03], [255, 510, 765], "max edge case")
    ]

    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set input array elements individually
            for j in range(4):
                dut.arr_in[j].value = inp[j]
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                done_count = 0
                max_cycles = 100
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_count += 1
                        break
                if done_count == 0:
                    raise TestFailure(f"Timeout waiting for done")
            else:
                await Timer(100, units='ns')
            
            # Read result array
            if not is_value_defined(dut.result[0].value):
                raise TestFailure("Result undefined")
            
            results = []
            for j in range(3):
                val = int(dut.result[j].value)
                results.append(val)
                
            if results != exp:
                raise TestFailure(f"Expected {exp}, got {results}")
            passed += 1
            cocotb.log.info(f"  PASS: {results}")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")