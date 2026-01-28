module text_match_wordz_middle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_data[0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SCAN     = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] current_idx;
    reg found_z;
    reg [7:0] char_val;
    reg [3:0] len_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational logic for character comparison
    always @(*) begin
        if (current_idx < 4'd16) begin
            char_val = char_data[current_idx];
        end else begin
            char_val = 8'd0;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len < 3) begin
                        next_state = FINISH;
                    end else begin
                        next_state = SCAN;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            SCAN: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (found_z || (current_idx >= len_reg - 4'd1)) begin
                    next_state = FINISH;
                end else begin
                    next_state = SCAN;
                end
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
            result <= 1'b0;
            done <= 1'b0;
            current_idx <= 4'd1;
            found_z <= 1'b0;
            len_reg <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    found_z <= 1'b0;
                    result <= 1'b0;
                    
                    if (start) begin
                        len_reg <= len;
                        current_idx <= 4'd1;
                    end
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check current character
                    if (char_val == 8'd122) begin
                        found_z <= 1'b1;
                        result <= 1'b1;
                    end
                    
                    // Move to next index
                    if (!found_z && current_idx < len_reg - 4'd1) begin
                        current_idx <= current_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    
                    // If we haven't found z yet, result remains 0
                    // If we found it in SCAN, result stays 1
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule