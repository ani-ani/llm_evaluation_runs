module bracket_nested_checker (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0][7:0] char_array,
    output reg result,
    output reg done
);

parameter IDLE = 2'd0, PROCESSING = 2'd1, DONE = 2'd2;

reg [1:0] state;
reg [7:0] char_reg [7:0];
reg [2:0] index;
reg [2:0] depth;
reg nested_flag;
reg valid_flag;

assign done = (state == DONE);
assign result = (state == DONE) ? (valid_flag && nested_flag && (depth ==0)) : 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        char_reg <= 0;
        index <=0;
        depth <=0;
        valid_flag <=1;
        nested_flag <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESSING;
                char_reg <= char_array;
                index <=0;
                depth <=0;
                valid_flag <=1;
                nested_flag <=0;
            end
        end else if (state == PROCESSING) begin
            if (index <8) begin
                logic [7:0] current_char = char_reg[index];
                if (current_char == 8'h5B) begin // '['
                    depth <= depth +1;
                    if (depth >1) begin
                        nested_flag <=1;
                    end
                end else if (current_char ==8'h5D) begin // ']'
                    if (depth ==0) begin
                        valid_flag <=0;
                    end
                    depth <= depth -1;
                end
                index <= index +1;
                if (index ==8) begin
                    state <= DONE;
                end
            end else begin
                state <= DONE;
            end
        end
    end
end

endmodule