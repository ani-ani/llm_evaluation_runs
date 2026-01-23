module round_and_sum (
    input reg clk,
    input reg rst_n, // active low
    input reg start,
    input reg [2:0] list_length,
    input reg [31:0] list_data [0:7],
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam LOAD = 3'd1;
localparam ROUNDING = 3'd2;
localparam SUMMING = 3'd3;
localparam MULTIPLYING = 3'd4;
localparam DONE = 3'd5;

reg [2:0] state_reg;
reg [2:0] list_length_reg;
reg [31:0] list_data_reg [0:7];
reg [31:0] sum_reg;
reg [3:0] index_reg;
reg [31:0] result_reg;
reg done_reg;

initial begin
    state_reg = IDLE;
    list_length_reg = 3'b0;
    list_data_reg = 32'd0;
    sum_reg = 32'd0;
    index_reg = 4'd0;
    result_reg = 32'd0;
    done_reg = 1'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        list_length_reg <= 3'b0;
        list_data_reg <= 32'd0;
        sum_reg <= 32'd0;
        index_reg <= 4'd0;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= LOAD;
                end else begin
                    state_reg <= IDLE;
                end
            end
            LOAD: begin
                list_length_reg <= list_length;
                list_data_reg <= list_data;
                state_reg <= ROUNDING;
            end
            ROUNDING: begin
                if (index_reg < list_length_reg) begin
                    reg [31:0] current_data = list_data_reg[index_reg];
                    reg [15:0] rounded_val;
                    rounded_val = (current_data + 32'd0x8000) >>> 16;
                    sum_reg <= sum_reg + rounded_val;
                    index_reg <= index_reg + 1;
                    state_reg <= ROUNDING;
                end else begin
                    state_reg <= SUMMING;
                end
            end
            SUMMING: begin
                state_reg <= MULTIPLYING;
            end
            MULTIPLYING: begin
                reg [47:0] product;
                product = (sum_reg) * (list_length_reg);
                result_reg <= product << 16;
                state_reg <= DONE;
                done_reg <= 1'b1;
            end
            DONE: begin
                state_reg <= DONE;
                done_reg <= 1'b1;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule