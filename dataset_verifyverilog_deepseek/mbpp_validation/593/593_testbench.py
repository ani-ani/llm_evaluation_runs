import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import re

async def apply_reset(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def str_to_bytes(ip_str):
    # Pad each segment to 3 ASCII characters
    segments = ip_str.split('.')
    padded = [s.ljust(3, '\\0') for s in segments]
    flat = ''.join(padded)
    return int.from_bytes(flat.encode('ascii'), 'big')

@cocotb.test()
async def test_ip_cleaner(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await apply_reset(dut)
    
    # Test cases (original modified to fit 3-digit segments)
    test_cases = [
        ("216.08.094.196", "216.8.94.196"),
        ("12.01.024", "12.1.24\\0"),  # Pad last segment
        ("00.01.000.1", "0.1.0.1\\0"),  # All-zero segment
    ]
    
    passed = 0
    for ip_in, expected_out in test_cases:
        # Convert to byte format
        input_bytes = str_to_bytes(ip_in)
        expected_bytes = str_to_bytes(expected_out)
        
        # Apply inputs
        dut.ip_bytes.value = input_bytes
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing
        for _ in range(18):  # 16 cycles + margin
            await RisingEdge(dut.clk)
            
        # Check outputs
        if dut.done.value != 1:
            dut._log.error(f"FAIL: Done not asserted for {ip_in}")
        elif dut.clean_bytes.value != expected_bytes:
            actual = dut.clean_bytes.value.buff
            actual_str = actual.decode('ascii').replace('\\x00', '')
            dut._log.error(f"FAIL: {ip_in} => {actual_str}, expected {expected_out}")
        else:
            passed += 1
            dut._log.info(f"PASS: {ip_in} => {expected_out}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")