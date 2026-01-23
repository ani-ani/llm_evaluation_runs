module parse_nested_parens (input clk, input rst_n, input start, input [6:0] char_in, input valid, input done_in, output reg [3:0] result, output reg done, output reg [2:0] group_count);

reg [3:0] max_depth;
reg [15:0] current_depth;
reg done_reg;

localparam IDLE = 2'd0;
localparam PARSE = 2'd1;
localparam WAIT_SPACE = 2'd2;
localparam COMPLETE = 2'd3;

reg [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        max_depth <= 4'd0;
        current_depth <= 16'd0;
        group_count <= 3'd0;
        done_reg <= 1'b0;
    end else begin
        case(state)
            IDLE: 
                if (start)
                    state <= PARSE;
                else
                    state <= IDLE;
            PARSE: 
                if (valid) begin
                    integer char_val = char_in;
                    if (char_val == 40) begin // '('
                        current_depth <= current_depth + 1;
                        if (current_depth + 1 > max_depth)
                            max_depth <= current_depth + 1;
                        else
                            max_depth <= max_depth;
                    end else if (char_val == 41) begin // ')'
                        current_depth <= current_depth - 1;
                    end else if (char_val == 32) begin // space
                        group_count <= group_count + 1;
                        current_depth <= 16'd0;
                        state <= WAIT_SPACE;
                    end
                end
                if (done_in) begin
                    if (current_depth != 16'd0) begin
                        group_count <= group_count + 1;
                        current_depth <= 16'd0;
                    end
                    state <= COMPLETE;
                    done_reg <= 1'b1;
                end else begin
                    state <= PARSE;
                end
            WAIT_SPACE: 
                if (valid) begin
                    integer char_val = char_in;
                    if (char_val == 32) begin // another space, stay
                        state <= WAIT_SPACE;
                    end else begin // it's a '(' or ')', return to PARSE
                        state <= PARSE;
                    end
                end else begin
                    // invalid character, stay in WAIT_SPACE
                    state <= WAIT_SPACE;
                end
                if (done_in) begin
                    state <= COMPLETE;
                    done_reg <= 1'b1;
                end
            COMPLETE:
                state <= COMPLETE;
        endcase
    end
end

assign result = max_depth;
assign done = done_reg;
endmodule