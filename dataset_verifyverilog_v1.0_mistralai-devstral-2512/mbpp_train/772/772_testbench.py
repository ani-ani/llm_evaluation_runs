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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Constants
DATA_WIDTH = 8
MAX_CHARS = 64
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_remove_length(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("This problem requires sequential processing, module must be sequential")

    test_cases = [
        ('The person is most value tet', 3, 'person is most value'),
        ('If you told me about this ok', 4, 'If you me about ok'),
        ('Forces of darkeness is come into the play', 4, 'Forces of darkeness is the'),
        ('abc def ghi', 3, ''),
        ('test', 0, 'test'),  # K=0 removes nothing (no 0-length words)
        ('a bb ccc dddd', 2, 'a ccc dddd'),
        ('', 5, ''),  # Empty input
    ]

    passed = failed = 0
    for i, (test_str, K, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{test_str}' with K={K}")
        try:
            # Reset
            await reset_dut(dut, cycles=1)
            
            # Set K
            if has_signal(dut, 'K'):
                dut.K.value = clamp_to_width(K, 4)
            else:
                raise TestFailure("Signal 'K' not found")
            
            # Set start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Drive input characters over 64 cycles
            chars = list(test_str.encode('ascii'))
            for cyc in range(MAX_CHARS):
                if cyc < len(chars):
                    dut.char_in.value = clamp_to_width(chars[cyc], DATA_WIDTH)
                else:
                    dut.char_in.value = 0  # Null padding
                await RisingEdge(dut.clk)
            
            # Now read output stream
            out_chars = []
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                    if is_value_defined(dut.char_out.value):
                        val = int(dut.char_out.value)
                        if 32 <= val < 128:  # Printable ASCII
                            out_chars.append(chr(val))
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            out_str = ''.join(out_chars).strip()
            expected_str = expected.strip()
            
            if out_str != expected_str:
                raise TestFailure(f"Expected '{expected_str}', got '{out_str}'")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")