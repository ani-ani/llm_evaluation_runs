import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_file_checker(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper to pad strings
    def pad(s):
        return s.ljust(16, '\\0')
    
    test_cases = [
        (pad("example.txt"), 1),  # Yes
        (pad("1example.dll"), 0),  # No (prefix starts with digit)
        (pad("K.dll"), 1),  # Yes
        (pad("MY16FILE3.exe"), 1),  # Yes (exactly 3 digits)
        (pad("His12FILE94.exe"), 0),  # No (4 digits)
        (pad("_Y.txt"), 0),  # No (prefix starts with _)
        (pad("valid.txt"), 1),  # Yes
        (pad("invalid.exe.txt"), 0),  # No (multiple dots)
        (pad("nodots"), 0),  # No (no dot)
        (pad("a.txt"), 1)  # Yes (min valid case)
    ]
    
    passed = 0
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for name_bytes, expected in test_cases:
        # Convert string to 128-bit vector
        name_int = int.from_bytes(name_bytes.encode(), byteorder='big')
        dut.file_name.value = name_int
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 17 cycles for result
        for _ in range(17):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.valid.value == expected:
            passed += 1
            dut._log.info(f"PASS: {name_bytes} => {expected}")
        else:
            dut._log.error(f"FAIL: {name_bytes} => {dut.valid.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")