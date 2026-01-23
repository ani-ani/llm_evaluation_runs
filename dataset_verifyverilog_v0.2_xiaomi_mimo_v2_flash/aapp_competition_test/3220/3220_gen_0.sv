module circle_dance_solver (
    input clk,
    input rst_n,
    input start_load,
    input [2:0] addr,
    input [2:0] p_in,
    input write_en,
    output reg [7:0] solution_mask,
    output reg valid,
    output reg done
);

    // Internal memory for p values (depth 8, width 3)
    reg [2:0] p_mem [0:7];
    
    // State definitions
    localparam IDLE      = 3'b000;
    localparam CHECKING  = 3'b001;
    localparam FOUND     = 3'b010;
    localparam NO_SOLUTION = 3'b011;
    localparam DONE      = 3'b100;
    
    reg [2:0] state;
    reg [7:0] mask_iter; // Iterates 0 to 255
    
    // Result accumulation
    reg [7:0] candidate_mask;
    
    // Internal wires for parallel destination calculation to avoid large combinational logic in always block
    wire [2:0] dest [0:7];
    wire [2:0] dest_next [0:7];
    
    // Boolean flags for uniqueness check
    reg collision_detected;
    
    integer i;

    // Parallel Destination Calculation Logic
    // This unrolls the loop for synthesis, evaluating all 8 destinations simultaneously.
    // We calculate destinations for the *next* mask (mask_iter + 1) in parallel.
    // This allows checking the validity of a mask in essentially zero logic delay (just comparators).
    // However, to find the *smallest* mask, we actually need to check the *current* mask_iter.
    // Let's compute based on mask_iter.
    
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_dest
            // If bit is 0 (L): dest = i - p
            // If bit is 1 (R): dest = i + p
            // We handle modulo 8. 
            // Since inputs are 0-7, i +/- p ranges -7 to 14.
            // We can calculate it carefully.
            assign dest[g] = (mask_iter[g] == 0) ? 
                             ((g >= p_mem[g]) ? (g - p_mem[g]) : (g - p_mem[g] + 8)) : 
                             ((g + p_mem[g] < 8) ? (g + p_mem[g]) : (g + p_mem[g]) - 8);
        end
    endgenerate

    // Collision Detection Logic
    // Checks if all elements in dest array are unique.
    // Since N=8 is small, we can use a combinational block checking pairs.
    always @(*) begin
        collision_detected = 0;
        // Check all pairs (i, j) where i < j
        // This is O(N^2) but N=8, so 28 comparisons. Very fast.
        for (i = 0; i < 8; i = i + 1) begin
            for (int j = i + 1; j < 8; j = j + 1) begin
                if (dest[i] == dest[j]) begin
                    collision_detected = 1;
                end
            end
        end
    end

    // Sequential State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            solution_mask <= 8'h00;
            mask_iter <= 8'h00;
            // Clear memory (optional, but good practice for reset)
            for (int k = 0; k < 8; k++) p_mem[k] <= 3'b000;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    done <= 0;
                    if (start_load) begin
                        state <= IDLE; // Stay in IDLE or switch to a LOAD state if needed.
                        // Since the prompt implies external writes via addr/data_in/write_en,
                        // we stay in IDLE while those signals are manipulated by the testbench.
                        // The 'start_load' signal is just to reset flags.
                        mask_iter <= 8'h00;
                        solution_mask <= 8'h00;
                    end else if (!start_load && write_en && addr == 3'b111) begin
                        // Example trigger: If we write to address 7, we assume loading is done and start.
                        // Or simpler: Use start_load pulse to transition to CHECKING.
                        // Let's interpret the spec: "Revised Interface" implies we stay in IDLE until 
                        // logic dictates transition. Let's assume we need a specific trigger.
                        // To be safe and generic: The module just stays in IDLE accepting writes.
                        // The testbench must signal 'done loading' somehow. 
                        // Since the prompt asks for 'load start' input, let's assume 'start_load' 
                        // is a pulse that initiates the solve sequence AFTER data is loaded.
                        // Wait, the prompt says: "On start, it should iterate...".
                        // Let's change IDLE logic: if start_load is high, transition to CHECKING.
                    end
                end
                
                // We split IDLE to handle the write logic cleanly.
                // If write_en is high, we update p_mem.
                // If start_load is high, we go to CHECKING.
                // Since we can't do both in one block easily without careful priority:
                // The logic below assumes 'start_load' transitions to CHECKING.
                // Writes are handled in parallel in a separate always block or checking priority.
            endcase
        end
    end

    // Re-writing the FSM to handle the specific requirements clearly
    // State: IDLE (wait for start_load signal to high)
    //        While in IDLE, we can write to p_mem using write_en.
    //        When start_load goes high, transition to CHECKING.
    //        CHECKING: Iterate mask 0..255.
    //        FOUND: Store result.
    //        NO_SOLUTION: Set flags.
    //        DONE: Assert done.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            no_solution <= 0;
            solution_mask <= 8'h00;
            mask_iter <= 8'h00;
            // p_mem reset is optional but good practice. We assume testbench loads values.
        end else begin
            // Default assignments
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    no_solution <= 0;
                    mask_iter <= 8'h00;
                    
                    // Handle memory writes in IDLE
                    if (write_en) begin
                        p_mem[addr] <= p_in;
                    end
                    
                    // Transition to checking when start_load is asserted
                    if (start_load) begin
                        state <= CHECKING;
                    end
                end

                CHECKING: begin
                    // We are checking 'mask_iter' now.
                    // If no collision, this is the lexicographically smallest (first found).
                    if (!collision_detected) begin
                        solution_mask <= mask_iter;
                        state <= FOUND;
                    end else begin
                        // If collision, try next mask
                        if (mask_iter == 8'hFF) begin
                            // We checked 0 to 255 (0xFF). 
                            // Note: loop goes 0->255. When mask_iter is 255, we check it.
                            // If 255 fails, we are done with no solution.
                            state <= NO_SOLUTION;
                        end else begin
                            mask_iter <= mask_iter + 1;
                            state <= CHECKING;
                        end
                    end
                end

                FOUND: begin
                    valid <= 1;
                    done <= 1;
                    state <= DONE;
                end

                NO_SOLUTION: begin
                    no_solution <= 1;
                    done <= 1;
                    state <= DONE;
                end

                DONE: begin
                    // Wait for reset or new start_load cycle.
                    // To allow restart, we stay here until start_load goes low then high again?
                    // Or simply wait for reset.
                    // Let's allow return to IDLE if start_load goes low.
                    if (!start_load) begin
                         state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Handle the edge case of checking mask 0xFF in CHECKING state logic:
    // The code above transitions to NO_SOLUTION if mask_iter is 0xFF AND collision_detected.
    // What if mask_iter is 0xFE and collision_detected? We increment to 0xFF.
    // In the next cycle, we check 0xFF.
    // If 0xFF is valid, we go FOUND. If invalid, we go NO_SOLUTION.
    // The logic seems correct.

    // One refinement: If mask_iter starts at 0 and goes to 255, that's 256 iterations.
    // Logic is correct.

endmodule