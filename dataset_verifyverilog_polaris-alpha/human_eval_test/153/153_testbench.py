import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

def pad_string(s, length=16):
    return s.ljust(length, '\\0')

@cocotb.test()
async def test_strongest(dut):
    # Test cases (padded to 16 chars, truncated if necessary)
    test_cases = [
        ('Watashi', [pad_string('tEN'), pad_string('niNE'), pad_string('eIGHt8OKe')] + ['\\0'*16]*5, 3, 'Watashi.eIGHt8OKe'),
        ('Boku123', [pad_string('nani'), pad_string('NazeDa'), pad_string('YEs.WeCaNe'), pad_string('32145tggg')] + ['\\0'*16]*4, 4, 'Boku123.YEs.WeCaNe'),
        ('Sp', [pad_string('671235'), pad_string('Bb')] + ['\\0'*16]*6, 2, 'Sp.671235')
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for class_name, extensions, num_ext, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Convert strings to bytes
        cn_bytes = class_name.encode('ascii').ljust(16, b'\\0')
        ext_bytes = b''.join([e.encode('ascii').ljust(16, b'\\0') for e in extensions])
        
        # Assign inputs
        dut.class_name.value = int.from_bytes(cn_bytes, 'big')
        dut.extensions.value = int.from_bytes(ext_bytes, 'big')
        dut.num_extensions.value = num_ext
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        idx = dut.strongest_idx.value.integer
        selected_ext = extensions[idx].strip('\\0')
        result = f"{class_name.strip('\\0')}.{selected_ext}"
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {result} == {expected}")
        else:
            dut._log.error(f"FAIL: {result} != {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)