import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_fluttershy_scheduling(dut):
    """Test the Fluttershy Scheduling Accelerator"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz
    cocotb.start_soon(clock.start())

    # Helper to map inputs
    # Original problem values are huge, we'll use scaled values (divide by 1000)
    # P = [10, 20, 30], R = [5, 5, 10]
    # Scaled P = [10, 20, 30], Scaled R = [5, 5, 10]
    
    P_scaled = [10, 20, 30]
    R_scaled = [5, 5, 10]
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.in_valid.value = 0
    dut.config_p_in.value = 0
    dut.config_r_in.value = 0
    dut.customer_type_in.value = 0
    dut.customer_time_in.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load Configuration
    # Config inputs are arrays. In Python/cocotb we need to pack them or set per index.
    # Assuming packed array logic or iterating.
    # Let's assume we can set the whole vector or index it.
    # The prompt says [M-1:0][31:0]. 
    # For testbench simplicity, we will set values.
    # Since M=3, we have indices 0, 1, 2.
    
    # To set array in cocotb: usually dut.sig[i].value = val
    # But let's assume we can set the vector if it's a logic vector.
    # If it's an unpacked array, we need to iterate.
    # Let's write it to handle both via the dut object access.
    
    dut._log.info("Loading Configuration")
    # Try to access as list if unpacked array, else as int vector
    # We will assume standard ModelSim/VPI behavior where we can index sub-registers
    try:
        for i in range(3):
            dut.config_p_in[i].value = P_scaled[i]
            dut.config_r_in[i].value = R_scaled[i]
    except Exception:
        # Fallback for packed vector (unlikely for 2D array but safe)
        # If packed, we'd pack bits. Here we assume unpacked.
        pass

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Input Customers
    # Customers = [(2,20), (1,30), (1,32), (3,120)]
    # Types are 1-based in text, 0-based in code usually. Let's use 0-based internally.
    # (Type 2 -> 1, Type 1 -> 0, Type 3 -> 2)
    # Wait for in_ready to be high
    
    customers = [
        (1, 20), # Type 2 -> index 1
        (0, 30), # Type 1 -> index 0
        (0, 32), # Type 1 -> index 0
        (2, 120) # Type 3 -> index 2
    ]
    
    dut._log.info("Sending Customers")
    for c_type, c_time in customers:
        # Wait for ready
        timeout = 0
        while not dut.in_ready.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            dut._log.error("Timeout waiting for in_ready")
            assert False
            
        dut.customer_type_in.value = c_type
        dut.customer_time_in.value = c_time
        dut.in_valid.value = 1
        await RisingEdge(dut.clk)
        dut.in_valid.value = 0
        
    # Send a terminator (type 0 might be valid, let's use a convention or just wait for done)
    # The prompt says 'customer_type_in 0 means invalid/end' or we rely on fixed N=16?
    # Let's send a few dummy cycles or wait for done signal.
    
    # Wait for result_valid
    dut._log.info("Waiting for result")
    timeout = 0
    while not dut.result_valid.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.result_valid.value == 1, "Result valid did not go high"
    
    result = dut.result.value
    dut._log.info(f"Result: {result}")
    
    # Expected output from example: 3
    assert result == 3, f"Expected 3, got {result}"

@cocotb.test()
async def test_fluttershy_all_same(dut):
    """Test case where all customers are same type and arrive same time"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.in_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load Config: P=[10], R=[10]
    # Assuming M=1
    try:
        dut.config_p_in[0].value = 10
        dut.config_r_in[0].value = 10
    except Exception:
        pass
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # 3 customers of type 0 at time 10
    for _ in range(3):
        while not dut.in_ready.value:
            await RisingEdge(dut.clk)
        dut.customer_type_in.value = 0
        dut.customer_time_in.value = 10
        dut.in_valid.value = 1
        await RisingEdge(dut.clk)
        dut.in_valid.value = 0
        
    # Wait for result
    while not dut.result_valid.value:
        await RisingEdge(dut.clk)
        
    # Expected: 3
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
