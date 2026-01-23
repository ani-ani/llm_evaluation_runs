module boredom_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data,
    input [3:0] char_index,
    input char_valid,
    output reg [3:0] boredom_count,
    output reg done,
    output reg error
);

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE_STATE = 2'd2;

reg [1:0] state;
reg [3:0] boredom_count_reg;
reg done_reg;
reg error_reg;
reg after_delimiter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        boredom_count_reg <= 4'd0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
        after_delimiter <= 1'b0;
    end
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            state <= PROCESSING;
            boredom_count_reg <= 4'd0;
            after_delimiter <= 1'b1;
        end
    end else if (state == PROCESSING) begin
        if (char_valid) begin
            localparam DELIMITER = 8'h2E | 8x3F | 8x21;
            localparam SPACE = 8x20;

            if (char_data == DELIMITER) begin
                after_delimiter <= 1'b1;
            end else if (char_data == SPACE) begin
                // Do nothing
            end else begin
                if (after_delimiter) begin
                    if (char_data == 8x49) begin
                        boredom_count_reg <= boredom_count_reg + 1;
                    end
                    after_delimiter <= 1'b0;
                end
            end

            if (char_index == 15) begin
                done_reg <= 1'b1;
                state <= DONE_STATE;
            end
        end
    end else if (state == DONE_STATE) begin
        // Stay in done
    end
end

assign boredom_count = boredom_count_reg;
assign done = done_reg;
assign error = error_reg;

endmodule