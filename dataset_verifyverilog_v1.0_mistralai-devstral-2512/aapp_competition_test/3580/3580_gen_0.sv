module LongestConsecutiveSubsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a_len,
    input wire [7:0] q_idx,
    input wire [7:0] query_i,
    input wire [3:0] query_m,
    input wire [7:0] arr_a [0:15],
    input wire [7:0] arr_b [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] current_pos;
    reg [7:0] match_count;
    reg [3:0] subset_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            current_pos <= 8'd0;
            match_count <= 8'd0;
            subset_idx <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                result = 8'd0;
                current_pos = 8'd0;
                match_count = 8'd0;
                subset_idx = 4'd0;
                cycle_count = 8'd0;
                
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                cycle_count = cycle_count + 8'd1;
                
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    if (current_pos == 8'd0) begin
                        // Initialize starting position (convert to 0-based)
                        current_pos = query_i - 8'd1;
                        match_count = 8'd0;
                    end
                    
                    // Check if current position is within array bounds
                    if (current_pos < a_len) begin
                        // Check if arr_a[current_pos] matches any element in arr_b
                        if (arr_a[current_pos] == arr_b[subset_idx]) begin
                            // Found a match, increment count and move to next position
                            match_count = match_count + 8'd1;
                            current_pos = current_pos + 8'd1;
                            subset_idx = 4'd0;
                        end else begin
                            // Check next subset element
                            if (subset_idx < query_m - 4'd1) begin
                                subset_idx = subset_idx + 4'd1;
                            end else begin
                                // No match found, end of consecutive sequence
                                next_state = FINISH;
                            end
                        end
                    end else begin
                        // Reached end of array
                        next_state = FINISH;
                    end
                end
            end
            
            FINISH: begin
                done = 1'b1;
                result = match_count;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                done = 1'b0;
                result = 8'd0;
            end
        endcase
    end

endmodule