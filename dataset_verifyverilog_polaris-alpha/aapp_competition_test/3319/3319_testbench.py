import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_planet_collision(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled versions)
    test_inputs = [
        # Test 1: 2 planetoids that collide
        {
            'masses': [12, 10, 0, 0],
            'positions': [(4,1,4), (1,2,1), (0,0,0), (0,0,0)],
            'velocities': [(5,3,-2), (8,-6,1), (0,0,0), (0,0,0)]
        },
        # Test 2: 2 planetoids that don't collide
        {
            'masses': [10, 15, 0, 0],
            'positions': [(1,0,0), (2,0,0), (0,0,0), (0,0,0)],
            'velocities': [(2,0,0), (4,0,0), (0,0,0), (0,0,0)]
        }
    ]
    expected_outputs = [
        {'count': 1, 'planets': [(22, (1,4,2), (6,-1,0))]},
        {'count': 2, 'planets': [(15, (2,0,0), (4,0,0)), (10, (1,0,0), (2,0,0))]}
    ]
    
    # Common test procedure
    async def run_test_case(test_idx):
        dut._log.info(f"Testing case {test_idx}")
        data = test_inputs[test_idx]
        exp = expected_outputs[test_idx]
        
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(4):
            dut.masses_in[i].value = data['masses'][i]
            dut.x_in[i].value = data['positions'][i][0]
            dut.y_in[i].value = data['positions'][i][1]
            dut.z_in[i].value = data['positions'][i][2]
            dut.vx_in[i].value = data['velocities'][i][0]
            dut.vy_in[i].value = data['velocities'][i][1]
            dut.vz_in[i].value = data['velocities'][i][2]
        
        # Start simulation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (timeout after 20 cycles)
        timeout = 20
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        assert timeout > 0, "Simulation timed out"
        
        # Verify outputs
        planet_count = dut.planet_count.value
        assert planet_count == exp['count'], "Planet count mismatch: %d vs %d" % (planet_count, exp['count'])
        
        planets_found = []
        for i in range(planet_count):
            mass = dut.masses_out[i].value
            x = dut.x_out[i].value
            y = dut.y_out[i].value
            z = dut.z_out[i].value
            vx = dut.vx_out[i].value.signed_integer
            vy = dut.vy_out[i].value.signed_integer
            vz = dut.vz_out[i].value.signed_integer
            planets_found.append((int(mass), (int(x), int(y), int(z)), (vx, vy, vz)))
        
        exp_planets = exp['planets']
        assert len(planets_found) == len(exp_planets), "Mismatched planet output count"
        
        for i, (found, expected) in enumerate(zip(planets_found, exp_planets)):
            assert found[0] == expected[0], f"Planet {i} mass mismatch: {found[0]} vs {expected[0]}"
            assert found[1] == expected[1], f"Planet {i} pos mismatch: {found[1]} vs {expected[1]}"
            assert found[2] == expected[2], f"Planet {i} vel mismatch: {found[2]} vs {expected[2]}"
        
        return True
    
    # Run all test cases
    passed = 0
    for i in range(len(test_inputs)):
        try:
            success = await run_test_case(i)
            passed += 1
        except AssertionError as e:
            dut._log.error(f"Test case {i} failed: {e}")
    
    dut._log.info(f"{passed}/{len(test_inputs)} tests passed")
