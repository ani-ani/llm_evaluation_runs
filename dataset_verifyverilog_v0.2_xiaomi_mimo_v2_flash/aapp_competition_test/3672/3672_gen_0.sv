module el_garizm_coexistence(
    input clk,
    input rst_n,
    input start,
    input [2:0] island_idx,
    input [2:0] resource_idx,
    input resource_valid,
    input input_done,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam INPUT = 3'b010;
    localparam VERIFY = 3'b100;
    localparam DONE = 3'b000; // Using 0 as done state for efficiency

    // Registers for state
    reg [2:0] state;
    reg [2:0] next_state;

    // Input storage: 8x8 adjacency matrix
    // adj_matrix[i][r] is 1 if resource r is on island i
    reg [7:0] adj_matrix [7:0];
    reg [7:0] next_adj_matrix [7:0];

    // Resource tracking to find pairs
    // resource_islands[r] stores the two islands for resource r
    // Upper 3 bits for first island, lower 3 bits for second island
    reg [5:0] resource_islands [7:0];
    reg [5:0] next_resource_islands [7:0];
    reg [2:0] resource_count [7:0];
    reg [2:0] next_resource_count [7:0];

    // Verification counters
    reg [7:0] assignment_counter;
    reg [7:0] next_assignment_counter;
    reg [2:0] resource_check_idx;
    reg [2:0] next_resource_check_idx;
    reg temp_valid; // Temporary valid flag for current assignment
    reg next_temp_valid;

    // Helper wires for verification
    wire [2:0] island1 = resource_islands[resource_check_idx][5:3];
    wire [2:0] island2 = resource_islands[resource_check_idx][2:0];
    wire bit1 = assignment_counter[island1];
    wire bit2 = assignment_counter[island2];
    wire resources_opposite = (bit1 != bit2);

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INPUT;
            end
            INPUT: begin
                if (input_done)
                    next_state = VERIFY;
            end
            VERIFY: begin
                // Iterate 256 assignments (0-255)
                // Iterate resources (0-7) for each assignment
                if (assignment_counter == 8'hFF && resource_check_idx == 3'd7) begin
                    next_state = DONE;
                end else begin
                    next_state = VERIFY;
                end
            end
            DONE: begin
                next_state = IDLE; // Self-reset or wait for next start
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            assignment_counter <= 8'h00;
            resource_check_idx <= 3'b0;
            temp_valid <= 1'b1; // Start valid
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 8'b0;
                resource_islands[i] <= 6'b0;
                resource_count[i] <= 3'b0;
            end
        end else begin
            state <= next_state;
            
            // Default assignments for registers
            // Initialize counters for VERIFY phase entry
            if (state != VERIFY && next_state == VERIFY) begin
                assignment_counter <= 8'h00;
                resource_check_idx <= 3'b0;
                temp_valid <= 1'b1;
            end

            case (state)
                INPUT: begin
                    if (resource_valid) begin
                        adj_matrix[island_idx][resource_idx] <= 1'b1;
                        
                        // Record island in resource_islands
                        if (resource_count[resource_idx] == 3'd0) begin
                            resource_islands[resource_idx][5:3] <= island_idx;
                            resource_count[resource_idx] <= 3'd1;
                        end else if (resource_count[resource_idx] == 3'd1) begin
                            resource_islands[resource_idx][2:0] <= island_idx;
                            resource_count[resource_idx] <= 3'd2;
                        end
                    end
                end

                VERIFY: begin
                    // Check resources for current assignment
                    if (resources_opposite) begin
                        // Resource valid, check next resource or next assignment
                        if (resource_check_idx == 3'd7) begin
                            // All resources valid for this assignment -> Solution found
                            result <= 1'b1;
                            // Move to next assignment (lazy evaluation, but we want to find if ANY exists)
                            // Since we found one, we can technically stop, but let's just set flag and continue to DONE
                            // Or we can jump to DONE. Let's accumulate result.
                            // If temp_valid was 1 (or set to 1), we found a valid one.
                            // To minimize logic, let's just set result if we find a valid one.
                            result <= 1'b1;
                            
                            assignment_counter <= assignment_counter + 1;
                            resource_check_idx <= 3'b0;
                        end else begin
                            resource_check_idx <= resource_check_idx + 1;
                        end
                    end else begin
                        // Current assignment invalid for this resource
                        // Skip to next assignment immediately to save cycles
                        assignment_counter <= assignment_counter + 1;
                        resource_check_idx <= 3'b0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // result is already set during VERIFY phase
                end
                
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    // Clear matrices on start if needed or rely on reset
                    // To allow re-use without full reset, clear on start
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            adj_matrix[i] <= 8'b0;
                            resource_islands[i] <= 6'b0;
                            resource_count[i] <= 3'b0;
                        end
                    end
                end
            endcase
        end
    end

endmodule
