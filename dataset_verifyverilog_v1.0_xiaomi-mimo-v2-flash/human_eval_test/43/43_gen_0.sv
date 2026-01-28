module find_zero_sum_pair (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] SCANNING   = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;
    
    // State register
    reg [1:0] state, next_state;
    
    // Control registers
    reg [3:0] i_counter, next_i_counter;
    reg [3:0] j_counter, next_j_counter;
    reg next_result;
    reg next_done;
    
    // Intermediate signals for pair checking
    wire signed [8:0] sum;
    wire pair_found;
    
    // Calculate sum and comparison
    assign sum = {arr[i_counter][7], arr[i_counter]} + {arr[j_counter][7], arr[j_counter]};
    assign pair_found = (sum == 9'sd0);
    
    // State transition logic (combinational)
    always @(*) begin
        next_state = state;
        next_i_counter = i_counter;
        next_j_counter = j_counter;
        next_result = result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                next_result = 1'b0;
                next_i_counter = 4'd0;
                next_j_counter = 4'd0;
                if (start) begin
                    next_state = SCANNING;
                    next_i_counter = 4'd0;
                    next_j_counter = 4'd1;
                end
            end
            
            SCANNING: begin
                if (len <= 4'd1) begin
                    // No pairs possible
                    next_state = COMPLETE;
                end else if (result) begin
                    // Early termination: found pair
                    next_state = COMPLETE;
                end else if (i_counter >= len - 4'd1) begin
                    // Exhausted all pairs
                    next_state = COMPLETE;
                end else if (pair_found) begin
                    // Found a pair
                    next_result = 1'b1;
                    next_state = COMPLETE;
                end else begin
                    // Continue scanning
                    if (j_counter >= len - 4'd1) begin
                        // Move to next i
                        next_i_counter = i_counter + 4'd1;
                        next_j_counter = i_counter + 4'd2;
                    end else begin
                        // Continue with current i
                        next_j_counter = j_counter + 4'd1;
                    end
                end
            end
            
            COMPLETE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic (state update and outputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i_counter <= next_i_counter;
            j_counter <= next_j_counter;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule