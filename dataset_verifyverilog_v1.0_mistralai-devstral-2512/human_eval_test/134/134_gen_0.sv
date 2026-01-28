module check_last_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in [0:15],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] CHECK_ALPHA = 3'd2;
    localparam [2:0] VERIFY_BOUNDARY = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] last_char;
    reg is_alpha;
    reg is_boundary;

    // Alphabetical character check
    wire is_alphabetical = (last_char >= 8'd65 && last_char <= 8'd90) || 
                           (last_char >= 8'd97 && last_char <= 8'd122);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            last_char <= 8'd0;
            is_alpha <= 1'b0;
            is_boundary <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= len - 4'd1;
                        next_state <= SEARCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SEARCH: begin
                    if (char_in[index] == 8'd32 && index > 4'd0) begin
                        index <= index - 4'd1;
                        next_state <= SEARCH;
                    end else if (char_in[index] == 8'd32 && index == 4'd0) begin
                        // No non-space character found
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end else begin
                        last_char <= char_in[index];
                        next_state <= CHECK_ALPHA;
                    end
                end
                
                CHECK_ALPHA: begin
                    is_alpha <= is_alphabetical;
                    if (is_alphabetical) begin
                        next_state <= VERIFY_BOUNDARY;
                    end else begin
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end
                
                VERIFY_BOUNDARY: begin
                    if (index == 4'd0) begin
                        is_boundary <= 1'b1;
                    end else if (char_in[index - 4'd1] == 8'd32) begin
                        is_boundary <= 1'b1;
                    end else begin
                        is_boundary <= 1'b0;
                    end
                    
                    result <= is_boundary;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule