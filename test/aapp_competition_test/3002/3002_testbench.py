import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_service_verifier(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock
    await cocotb.triggers.Timer(1, units="ns")
    
    test_cases = [
        (# Valid case (seems legit)
            [0x0001_0704, 0x0001_0708, 0x0001_0808],
            [0, 12000, 42000],
            0x00 # Expected output: seems legit
        ),
        (# Insufficient service
            [0x0001_0704, 0x0001_0708, 0x0001_0808],
            [0, 12000, 42001],
            0x01 # insufficient service
        ),
        (# Tampered case
            [0x0001_1711, 0x0001_1801],
            [0, 1000],
            0x02 # tampered odometer
        )
    ]
    
    for entries, odos, expected in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs (pad with zeros for 5 entries)
        for i in range(5):
            if i < len(entries):
                dut.years_months[i].value = entries[i]
                dut.odos[i].value = odos[i] if i < len(odos) else 0
            else:
                dut.years_months[i].value = 0
                dut.odos[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (10 cycles)
        for _ in range(12):
            await RisingEdge(dut.clk)
        
        # Check result
        result = dut.result.value.integer
        assert result in [0, 1, 2], "Invalid output state"
        if result != expected:
            raise cocotb.result.TestFailure(f"Expected {expected} got {result}")
    
    dut._log.info("3/3 tests passed")