module OverlapDetection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] list1 [0:7],
    input wire [7:0] list2 [0:7],
    input wire [2:0] len1,
    input wire [2:0] len2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] i;  // Outer loop counter (list1 index)
    reg [2:0] j;  // Inner loop counter (list2 index)
    reg found;    // Match found flag
    reg [7:0] compare_value;  // Storage for current list1 element
    reg [7:0] next_compare_value;
    reg [2:0] next_i, next_j;
    reg next_found;
    
    // State machine for comparison
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            found <= 1'b0;
            compare_value <= 8'd0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            found <= next_found;
            compare_value <= next_compare_value;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                end
                COMPARE: begin
                    // Result is set based on found flag
                    result <= found;
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        next_found = found;
        next_compare_value = compare_value;
        
        case (state)
            IDLE: begin
                next_found = 1'b0;
                next_i = 3'd0;
                next_j = 3'd0;
                next_compare_value = 8'd0;
                
                if (start) begin
                    if (len1 == 3'd0 || len2 == 3'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPARE;
                        next_i = 3'd0;
                        next_j = 3'd0;
                        next_compare_value = list1[0];
                    end
                end
            end
            
            COMPARE: begin
                // Compare current element
                if (list2[j] == compare_value) begin
                    next_found = 1'b1;
                end
                
                // Inner loop increment
                next_j = j + 3'd1;
                
                // Check if inner loop complete
                if (next_j >= len2) begin
                    next_j = 3'd0;
                    next_i = i + 3'd1;
                    
                    // Check if outer loop complete or found
                    if (next_found || next_i >= len1) begin
                        next_state = FINISH;
                    end else begin
                        next_compare_value = list1[next_i];
                    end
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_found = 1'b0;
                next_i = 3'd0;
                next_j = 3'd0;
                next_compare_value = 8'd0;
            end
        endcase
    end

endmodule