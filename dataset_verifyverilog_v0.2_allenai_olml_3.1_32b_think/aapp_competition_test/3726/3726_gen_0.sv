module snuke_flip_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] card_mask,
    output reg [7:0] result,
    output reg done
);

localparam IDLE = 2'd0;
localparam LOOKUP = 2'd1;
localparam DONE = 2'd2;

reg [2:0] state;
reg [7:0] temp_result;
reg [7:0] result_reg;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        temp_result <= 8'b0;
        result_reg <= 8'b0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            IDLE: 
                if (start) 
                    state <= LOOKUP;
                else 
                    state <= IDLE;
                temp_result <= 8'b0;
                result_reg <= 8'b0;
                done_reg <= 1'b0;
            LOOKUP: begin
                case(card_mask)
                    default: temp_result = 8'd0;
                endcase
                state <= DONE;
                result_reg <= 8'b0;
                done_reg <= 1'b0;
            end
            DONE: begin
                result_reg <= temp_result;
                done_reg <= 1'b1;
                state <= DONE;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule