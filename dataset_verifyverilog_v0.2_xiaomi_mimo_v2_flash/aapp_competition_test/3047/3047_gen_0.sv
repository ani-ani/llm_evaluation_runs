module lure_of_the_labyrinth (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    output reg [31:0] solution_count,
    output reg many,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam CHECK = 3'b010;
    localparam DONE = 3'b011;

    // Storage for inputs (20 entries max)
    reg [7:0] plate_data [0:19];
    reg [4:0] input_ptr;
    
    // Constraints check variables
    reg [7:0] p;
    reg [7:0] q;
    reg [4:0] idx; // index for iterating through stored data
    
    // State register
    reg [1:0] state;
    
    // Intermediate valid flag for current (p, q) pair
    wire current_pair_valid;
    
    // Flag to indicate if we have any known values
    reg known_values_present;

    // Combinational logic to check validity of current (p, q) against all inputs
    // We check if val * q % p == 0 for all known val.
    // If input is 0 (unknown), it is always valid (assumed to be integer base * p/q).
    assign current_pair_valid = (p != 0 && q != 0) && (idx < input_ptr) && 
                                ( (plate_data[idx] == 0) || 
                                  ((plate_data[idx] * q) % p == 0) );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_ptr <= 0;
            solution_count <= 0;
            many <= 0;
            done <= 0;
            p <= 1;
            q <= 1;
            idx <= 0;
            known_values_present <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    many <= 0;
                    if (start) begin
                        state <= COLLECT;
                        input_ptr <= 0;
                        known_values_present <= 0;
                    end
                end

                COLLECT: begin
                    if (valid_in) begin
                        plate_data[input_ptr] <= data_in;
                        if (data_in != 0) known_values_present <= 1;
                        input_ptr <= input_ptr + 1;
                    end
                    // Transition when we have collected 20 inputs or if we assume stream stops.
                    // Requirement says 20 plate entries.
                    if (input_ptr == 20 && !valid_in) begin // Wait for cycle after last valid
                        state <= CHECK;
                        solution_count <= 0;
                        p <= 1;
                        q <= 1;
                        idx <= 0;
                    end
                end

                CHECK: begin
                    // If no known values, infinite solutions (any p/q works)
                    if (!known_values_present) begin
                        many <= 1;
                        state <= DONE;
                    end else begin
                        // Algorithm: Iterate p (1..200), q (1..200)
                        // Check validity for each pair.
                        
                        // Check current pair against current index
                        if (current_pair_valid) begin
                            // If checked all indices for this pair, it's a valid solution
                            if (idx == input_ptr - 1) begin
                                solution_count <= solution_count + 1;
                                // Proceed to next q
                                if (q == 200) begin
                                    q <= 1;
                                    if (p == 200) begin
                                        state <= DONE;
                                    end else begin
                                        p <= p + 1;
                                        idx <= 0;
                                    end
                                end else begin
                                    q <= q + 1;
                                    idx <= 0;
                                end
                            end else begin
                                // Check next index for same (p, q)
                                idx <= idx + 1;
                            end
                        end else begin
                            // Current pair invalid, skip to next
                            // Note: We need to skip all remaining indices for this pair
                            // Since the logic is sequential, we effectively just move to next pair
                            // The logic inside 'if (current_pair_valid)' handles success case.
                            // Here we handle failure.
                            // Optimization: Just jump to next (p,q) immediately.
                            if (q == 200) begin
                                q <= 1;
                                if (p == 200) begin
                                    state <= DONE;
                                end else begin
                                    p <= p + 1;
                                end
                            end else begin
                                q <= q + 1;
                            end
                            // Reset index for the new pair
                            idx <= 0;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    if (start == 0) state <= IDLE; // Reset on start low
                end
            endcase
        end
    end

endmodule