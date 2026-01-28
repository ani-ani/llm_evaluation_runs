module palindrome_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] left_ptr, right_ptr;
    reg [2:0] comp_count;
    reg [7:0] temp_result;
    reg mismatch_detected;
    reg [3:0] cycle_counter;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            left_ptr <= 4'd0;
            right_ptr <= 4'd0;
            comp_count <= 3'd0;
            temp_result <= 8'd0;
            mismatch_detected <= 1'b0;
            cycle_counter <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        if (len == 4'd0) begin
                            // Empty string - palindrome
                            result <= 1'b1;
                        end else begin
                            result <= 1'b1; // Assume palindrome until proven otherwise
                            mismatch_detected <= 1'b0;
                        end
                        left_ptr <= 4'd0;
                        right_ptr <= (len - 4'd1);
                        comp_count <= 3'd0;
                    end
                end
                
                CHECKING: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Compare characters
                    if (!mismatch_detected) begin
                        if (str[left_ptr] != str[right_ptr]) begin
                            mismatch_detected <= 1'b1;
                            result <= 1'b0;
                        end
                    end
                    
                    // Update pointers for next comparison
                    left_ptr <= left_ptr + 4'd1;
                    right_ptr <= right_ptr - 4'd1;
                    comp_count <= comp_count + 3'd1;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len == 4'd0 || len == 4'd1) begin
                        // Empty or single char - complete immediately
                        next_state = COMPLETE;
                    end else begin
                        next_state = CHECKING;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECKING: begin
                // Check if we've completed comparisons
                // Number of comparisons needed = floor(len/2)
                // For len=2: need 1 comparison (comp_count=0 -> compare once)
                // For len=3: need 1 comparison
                // For len=4: need 2 comparisons
                // For len=8: need 4 comparisons
                
                if (len[0] == 1'b0) begin
                    // Even length: len/2 comparisons
                    if (comp_count >= (len >> 1) - 3'd1) begin
                        next_state = COMPLETE;
                    end else if (mismatch_detected) begin
                        next_state = COMPLETE;
                    end else begin
                        next_state = CHECKING;
                    end
                end else begin
                    // Odd length: (len-1)/2 comparisons
                    if (comp_count >= ((len - 4'd1) >> 1) - 3'd1) begin
                        next_state = COMPLETE;
                    end else if (mismatch_detected) begin
                        next_state = COMPLETE;
                    end else begin
                        next_state = CHECKING;
                    end
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule