module search_max_valid (
    input clk,
    input rst_n,
    input start,
    input [3:0] data_in,
    input [3:0] index,
    input valid_in,
    input done_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] freq [0:15];  // Frequency table for values 0-15
    reg [3:0] current_val;  // Current value being checked (15 down to 1)
    reg [2:0] check_count;  // Cycle counter for CHECK state (max 15)
    
    // Loop control
    reg checking_complete;
    reg found_match;
    
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                if (done_in)
                    next_state = CHECK;
                else
                    next_state = LOAD;
            end
            CHECK: begin
                if (checking_complete)
                    next_state = FINISH;
                else
                    next_state = CHECK;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'h00;
            done <= 1'b0;
            current_val <= 4'd15;
            check_count <= 3'd0;
            checking_complete <= 1'b0;
            found_match <= 1'b0;
            // Initialize frequency table
            for (i = 0; i < 16; i = i + 1) begin
                freq[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset frequency table on start
                        for (i = 0; i < 16; i = i + 1) begin
                            freq[i] <= 4'd0;
                        end
                    end
                end
                
                LOAD: begin
                    if (valid_in && (data_in != 4'd0)) begin
                        // Increment frequency for non-zero values
                        freq[data_in] <= freq[data_in] + 4'd1;
                    end
                end
                
                CHECK: begin
                    check_count <= check_count + 3'd1;
                    
                    if (check_count == 3'd0) begin
                        // First iteration: check V=15
                        current_val <= 4'd15;
                    end else begin
                        // Move to next value
                        current_val <= current_val - 4'd1;
                    end
                    
                    // Check if current value satisfies condition
                    if (!found_match && (freq[current_val] >= current_val) && (current_val != 4'd0)) begin
                        found_match <= 1'b1;
                    end
                    
                    // End condition: checked all 15 values (15 cycles) or found match
                    if (check_count >= 4'd14) begin // 14 + 1 = 15 cycles total
                        checking_complete <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (found_match) begin
                        result <= {4'd0, current_val};  // Extend to 8 bits
                    end else begin
                        result <= 8'hFF;  // -1
                    end
                    // Reset flags for next operation
                    found_match <= 1'b0;
                    checking_complete <= 1'b0;
                    check_count <= 3'd0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 8'h00;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule