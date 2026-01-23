module bureaucrat_stamp (
input clk,
input rst_n,
input start,
input [7:0][7:0] paper_grid,
output reg [7:0] min_nubs,
output reg done
);

localparam MAX_SIZE = 8;
localparam TOTAL_OFFSETS = 16*16;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam CALC_OFFSET = 3'd2;
localparam COMPUTE_STAMP = 3'd3;
localparam MIN_UPDATE = 3'd4;
localparam NEXT_OFFSET = 3'd5;
localparam DONE = 3'd6;

reg [2:0] state;
reg [7:0] min_nubs;
reg [7:0] current_min;
reg [7:0] temp_size;
reg [7:0] offset_index;
reg done_reg;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_nubs <= 8'd255;
        current_min <= 8'd255;
        offset_index <= 8'd0;
        done_reg <= 1'b0;
    end
end

always begin
    state <= state;
    min_nubs <= min_nubs;
    current_min <= current_min;
    offset_index <= offset_index;
    done_reg <= done_reg;
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) state <= INIT;
    end else if (state == INIT) begin
        offset_index <= 8'd0;
        current_min <= 8'd255;
        state <= CALC_OFFSET;
    end else if (state == CALC_OFFSET) begin
        if ( (offset_index >> 4) < 1 || (offset_index & 15) < 1 ) begin
            state <= NEXT_OFFSET;
        end else begin
            temp_size <= 8'd0;
            state <= MIN_UPDATE;
        end
    end else if (state == MIN_UPDATE) begin
        if (temp_size < current_min) current_min <= temp_size;
        state <= NEXT_OFFSET;
    end else if (state == NEXT_OFFSET) begin
        offset_index <= offset_index + 1;
        if (offset_index == TOTAL_OFFSETS) state <= DONE;
        else state <= CALC_OFFSET;
    end else if (state == DONE) begin
        min_nubs <= current_min;
        done_reg <= 1'b1;
        state <= IDLE;
    end
end

assign min_nubs = min_nubs;
assign done = done_reg;

endmodule