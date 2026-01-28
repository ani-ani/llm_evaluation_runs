module max_participants(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [63:0] edges_flat,
    output reg [3:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] INCREMENT = 3'd2;
    localparam [2:0] DONE = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] mask;
    reg [15:0] max_mask;
    reg [3:0] max_count;
    reg [3:0] popcount;
    reg valid_flag;
    reg [3:0] i_counter;  // Used for loops
    reg [3:0] j_counter;  // Used for inner loops
    reg [3:0] dependency;
    reg [3:0] temp_n;
    reg [3:0] temp_k;
    reg [63:0] temp_edges;
    reg [15:0] limit_mask;
    reg calculation_done;
    
    // Combinational logic for checking validity
    reg check_valid;
    reg [15:0] current_dep_mask;
    
    always @(*) begin
        // Default values
        check_valid = 1'b1;
        current_dep_mask = 16'd0;
        
        // For validity check: For each node i in mask, dependency must also be in mask
        // We check sequentially in the state machine
        if (state == CHECK && i_counter < temp_n) begin
            if (mask[i_counter]) begin
                // Extract dependency for i_counter
                dependency = edges_flat[i_counter*4 +: 4];
                // Check if dependency is in mask
                if (!mask[dependency]) begin
                    check_valid = 1'b0;
                end
            end
        end
    end
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            mask <= 16'd0;
            max_mask <= 16'd0;
            max_count <= 4'd0;
            popcount <= 4'd0;
            valid_flag <= 1'b0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            dependency <= 4'd0;
            temp_n <= 4'd0;
            temp_k <= 4'd0;
            temp_edges <= 64'd0;
            limit_mask <= 16'd0;
            calculation_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_n <= n;
                        temp_k <= k;
                        temp_edges <= edges_flat;
                        mask <= 16'd1;  // Start with mask 1
                        max_mask <= 16'd0;
                        max_count <= 4'd0;
                        limit_mask <= (1 << n) - 1;  // 2^n - 1
                        i_counter <= 4'd0;
                        j_counter <= 4'd0;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Calculate population count
                    if (i_counter < temp_n) begin
                        if (mask[i_counter]) begin
                            popcount <= popcount + 4'd1;
                        end
                        i_counter <= i_counter + 4'd1;
                    end else begin
                        // Population count complete
                        i_counter <= 4'd0;
                        if (popcount <= temp_k && popcount > 4'd0) begin
                            // Check validity
                            if (j_counter < temp_n) begin
                                if (mask[j_counter]) begin
                                    dependency = edges_flat[j_counter*4 +: 4];
                                    if (!mask[dependency]) begin
                                        valid_flag <= 1'b0;
                                        j_counter <= temp_n;  // Skip rest
                                    end else begin
                                        valid_flag <= 1'b1;
                                        j_counter <= j_counter + 4'd1;
                                    end
                                end else begin
                                    valid_flag <= 1'b1;
                                    j_counter <= j_counter + 4'd1;
                                end
                            end else begin
                                // Validity check complete
                                if (valid_flag && popcount > max_count) begin
                                    max_count <= popcount;
                                    max_mask <= mask;
                                end
                                state <= INCREMENT;
                            end
                        end else begin
                            // Popcount too large or zero, skip validity check
                            state <= INCREMENT;
                        end
                    end
                end
                
                INCREMENT: begin
                    // Reset counters for next iteration
                    popcount <= 4'd0;
                    valid_flag <= 1'b1;
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                    
                    // Increment mask
                    if (mask < limit_mask) begin
                        mask <= mask + 16'd1;
                        state <= CHECK;
                    end else begin
                        state <= DONE;
                        calculation_done <= 1'b1;
                    end
                end
                
                DONE: begin
                    result <= max_count;
                    done <= 1'b1;
                    state <= IDLE;
                    calculation_done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule