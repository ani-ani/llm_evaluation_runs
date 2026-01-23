module code_cracker (
    input clk,
    input rst_n,
    input start,
    input [3:0] row_addr,
    input [3:0] col_addr,
    input [3:0] data_in,
    input load_en,
    output reg [15:0] count,
    output reg done
);

reg [3:0][3:0] grid;

reg [3:0] zero_rows [7:0];
reg [3:0] zero_cols [7:0];
reg [3:0] zero_count;

reg [2:0] state;

localparam IDLE = 3'd0;
localparam FIND_ZEROS = 3'd1;
localparam SEARCH = 3'd2;
localparam CHECK = 3'd3;
localparam BACKTRACK = 3'd4;
localparam DONE_STATE = 3'd5;

reg [2:0] current_zero_idx;
reg [3:0] current_digit;
reg [3:0] stack [7:0];
reg [2:0] stack_ptr;

reg [15:0] internal_count;

assign count = internal_count;
assign done = (state == DONE_STATE);

always @(posedge clk) begin
    if (!rst_n) begin
        grid <= 16'b0;
        zero_count <= 4'd0;
        current_zero_idx <= 3'd0;
        current_digit <= 4'd0;
        stack <= 8*4'd0;
        stack_ptr <= 3'd0;
        state <= IDLE;
        internal_count <= 16'd0;
    end else if (load_en) begin
        grid[row_addr][col_addr] <= data_in;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= FIND_ZEROS;
            end
            FIND_ZEROS: begin
                state <= SEARCH;
            end
            SEARCH: begin
                if (current_digit < 4'd9) begin
                    current_digit <= current_digit + 1;
                end else begin
                    state <= DONE_STATE;
                end
            end
            CHECK: begin
                state <= SEARCH;
            end
            BACKTRACK: begin
                state <= SEARCH;
            end
            DONE_STATE: begin
            end
        endcase
    end
end

endmodule