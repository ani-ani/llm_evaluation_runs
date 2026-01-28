import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on Verilog spec
GRID_DIM = 8
MAX_PLANETOIDS = 16
DATA_WIDTH = 16
CLK_NS = 10

def pack_config(mass, x, y, z, vx, vy, vz, active=1):
    # Pack into 64-bit as per spec: vx[15:0], vy[15:0], vz[15:0], x[7:0], y[7:0], z[7:0], mass[7:0], active[0]
    # Note: Python integers are arbitrary precision, so bit operations are safe.
    config = 0
    config |= (vx & 0xFFFF) << (16*2) # vx shifted to high bits
    config |= (vy & 0xFFFF) << (16*1)
    config |= (vz & 0xFFFF) << (16*0)
    # NOTE: Spec sheet says x[7:0]... after vz. This implies 64-bit packing.
    # Let's assume the order is: [63:48] vx, [47:32] vy, [31:16] vz, [15:8] x, [7:0] y?
    # Re-reading spec: vx[15:0], vy[15:0], vz[15:0], x[7:0], y[7:0], z[7:0], mass[7:0], active[0]
    # That's 16+16+16+8+8+8+8+1 = 81 bits. Too wide.
    # Let's interpret it as 64-bit packed: 
    # [63:48] vx, [47:32] vy, [31:16] vz, [15:8] x/y/z/mass (packed) or just simplified.
    # ADAPTATION: Use 32-bit config for simplicity, or map strictly.
    # Let's use: [63:48] vx, [47:32] vy, [31:16] vz, [15:8] xyz (3x8 packed is 24 bits, won't fit)
    # Let's assume the prompt implies 64-bit width, but inputs fit in 32 bits.
    # I will pack: vx[15:0] in [31:16], vy[15:0] in [47:32], vz[15:0] in [63:48].
    # x, y, z, mass packed in lower bits [15:0] if we stick to 32-bit, or [31:0] for 32-bit bus.
    # RE-INTERPRETATION FOR 32-bit BUS (Standard in HDL):
    # [31:24] mass, [23:16] z, [15:8] y, [7:0] x. 
    # vx, vy, vz need separate inputs or wider bus. 
    # Let's stick to the spec's 64-bit description but limit to 32-bit for simulation ease if needed.
    # Actually, let's use 64-bit as requested, but pack intelligently.
    # Lower 32 bits: x, y, z, mass. 
    # Upper 32 bits: vx, vy, vz (16 bits each is 48 bits). 
    # This is tight. Let's reduce velocity to 10 bits (signed -512 to 512).
    # Or just pack vx, vy, vz into upper 48 bits of 64-bit int.
    
    # Let's stick to 64-bit as requested. 
    # [63:48] = vx, [47:32] = vy, [31:16] = vz. 
    # [15:0] is only 16 bits for x, y, z, mass (24 bits needed).
    # ADAPTATION: Pack x,y,z,mass into 32 bits. 
    # [31:24] mass, [23:16] z, [15:8] y, [7:0] x.
    # Total 32 bits. We can map this to the lower 32 bits of 64-bit config.
    
    lower = (mass << 24) | (z << 16) | (y << 8) | (x << 0)
    upper = (vz << 16) | (vy << 32) | (vx << 48)
    return upper | lower

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_planetoids(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 1
    # 2 8 8 8
    # 12 4 1 4 5 3 -2
    # 10 1 2 1 8 -6 1
    
    planetoids = [
        (12, 4, 1, 4, 5, 3, -2), # m, x, y, z, vx, vy, vz
        (10, 1, 2, 1, 8, -6, 1)
    ]
    
    num_p = len(planetoids)
    dut.num_planetoids.value = num_p
    
    # Configure
    for i, p in enumerate(planetoids):
        m, x, y, z, vx, vy, vz = p
        dut.config_addr.value = i
        dut.config_data.value = pack_config(m, x, y, z, vx, vy, vz)
        await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not int(dut.done.value) and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if timeout >= 2000:
        raise TestFailure("Simulation timed out")
        
    # Read results
    results = []
    result_timeout = 0
    while int(dut.result_valid.value) and result_timeout < 30:
        m = int(dut.result_mass.value)
        x = int(dut.result_x.value)
        y = int(dut.result_y.value)
        z = int(dut.result_z.value)
        vx = int(dut.result_vx.value)
        vy = int(dut.result_vy.value)
        vz = int(dut.result_vz.value)
        results.append((m, x, y, z, vx, vy, vz))
        await RisingEdge(dut.clk)
        result_timeout += 1
        
    # Verify Output
    # Expected: 1 planet, mass 22, loc (1,4,2), vel (6,-1,0)
    # Note: Location is at time of last collision. 
    # The sample output says "P0: 22 1 4 2 6 -1 0"
    
    if len(results) != 1:
        raise TestFailure(f"Expected 1 planet, got {len(results)}")
        
    res = results[0]
    if res[0] != 22: raise TestFailure(f"Mass mismatch: {res[0]} != 22")
    if res[1] != 1: raise TestFailure(f"X mismatch: {res[1]} != 1")
    if res[2] != 4: raise TestFailure(f"Y mismatch: {res[2]} != 4")
    if res[3] != 2: raise TestFailure(f"Z mismatch: {res[3]} != 2")
    if res[4] != 6: raise TestFailure(f"VX mismatch: {res[4]} != 6")
    if res[5] != -1: raise TestFailure(f"VY mismatch: {res[5]} != -1")
    if res[6] != 0: raise TestFailure(f"VZ mismatch: {res[6]} != 0")
    
    cocotb.log.info("Test Case 1 Passed")

    # --- Reset for Test Case 2 ---
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: No Collision (parallel lines)
    # 2 10 20 30
    # 10 1 0 0 2 0 0
    # 15 2 0 0 4 0 0
    
    planetoids2 = [
        (10, 1, 0, 0, 2, 0, 0),
        (15, 2, 0, 0, 4, 0, 0)
    ]
    
    num_p2 = len(planetoids2)
    dut.num_planetoids.value = num_p2
    
    for i, p in enumerate(planetoids2):
        m, x, y, z, vx, vy, vz = p
        dut.config_addr.value = i
        dut.config_data.value = pack_config(m, x, y, z, vx, vy, vz)
        await RisingEdge(dut.clk)
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not int(dut.done.value) and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if timeout >= 2000:
        raise TestFailure("Simulation timed out")
        
    # Read results
    results2 = []
    result_timeout = 0
    while int(dut.result_valid.value) and result_timeout < 30:
        m = int(dut.result_mass.value)
        x = int(dut.result_x.value)
        y = int(dut.result_y.value)
        z = int(dut.result_z.value)
        vx = int(dut.result_vx.value)
        vy = int(dut.result_vy.value)
        vz = int(dut.result_vz.value)
        results2.append((m, x, y, z, vx, vy, vz))
        await RisingEdge(dut.clk)
        result_timeout += 1
        
    # Verify
    if len(results2) != 2:
        raise TestFailure(f"Expected 2 planets, got {len(results2)}")
        
    # Sort check (expected output order: P0: 15..., P1: 10...)
    # Implementation should sort by mass desc.
    
    if results2[0][0] != 15: raise TestFailure(f"Mass mismatch: {results2[0][0]} != 15")
    if results2[1][0] != 10: raise TestFailure(f"Mass mismatch: {results2[1][0]} != 10")
    
    cocotb.log.info("Test Case 2 Passed")
