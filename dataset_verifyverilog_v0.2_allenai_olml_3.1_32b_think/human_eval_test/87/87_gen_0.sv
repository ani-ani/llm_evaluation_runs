module get_row (
    input clk,
    input rst_n, // active low
    input start,
    input [2:0] num_rows,
    input [2:0] row_lengths [0:7],
    input [7:0] lst [0:7][0:7],
    input [7:0] x,
    output reg [2:0] result_count,
    output reg [2:0] result_rows [0:7],
    output reg [2:0] result_cols [0:7],
    output reg done
);

// Internal registers
reg [2:0] row;
reg [2:0] col;
reg [2:0] match_rows [7:0];
reg [2:0] match_cols [7:0];
reg [2:0] match_count;

// State register
reg [7:0] state;
localparam IDLE = 8'd0;
localparam SCAN_ROW = 8'd1;
localparam SCAN_COL = 8'd2;
localparam CHECK_MATCH = 8'd3;
localparam STORE_MATCH = 8'd4;
localparam SORT_RESULTS = 8'd5;
localparam OUTPUT = 8'd6;
localparam DONE = 8'd7;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        row <= 3'd0;
        col <= 3'd0;
        match_count <= 3'd0;
        match_rows[0] <=3'd0; match_rows[1] <=3'd0; match_rows[2] <=3'd0; match_rows[3] <=3'd0;
        match_rows[4] <=3'd0; match_rows[5] <=3'd0; match_rows[6] <=3'd0; match_rows[7] <=3'd0;
        match_cols[0] <=3'd0; match_cols[1] <=3'd0; match_cols[2] <=3'd0; match_cols[3] <=3'd0;
        match_cols[4] <=3'd0; match_cols[5] <=3'd0; match_cols[6] <=3'd0; match_cols[7] <=3'd0;
        result_count <=3'd0;
        done <=1'b0;
        result_rows[0] <=3'd0; result_rows[1] <=3'd0; result_rows[2] <=3'd0; result_rows[3] <=3'd0;
        result_rows[4] <=3'd0; result_rows[5] <=3'd0; result_rows[6] <=3'd0; result_rows[7] <=3'd0;
        result_cols[0] <=3'd0; result_cols[1] <=3'd0; result_cols[2] <=3'd0; result_cols[3] <=3'd0;
        result_cols[4] <=3'd0; result_cols[5] <=3'd0; result_cols[6] <=3'd0; result_cols[7] <=3'd0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= SCAN_ROW;
                    row <=3'd0;
                    col <=3'd0;
                    match_count <=3'd0;
                    match_rows[0] <=3'd0; match_rows[1] <=3'd0; match_rows[2] <=3'd0; match_rows[3] <=3'd0;
                    match_rows[4] <=3'd0; match_rows[5] <=3'd0; match_rows[6] <=3'd0; match_rows[7] <=3'd0;
                    match_cols[0] <=3'd0; match_cols[1] <=3'd0; match_cols[2] <=3'd0; match_cols[3] <=3'd0;
                    match_cols[4] <=3'd0; match_cols[5] <=3'd0; match_cols[6] <=3'd0; match_cols[7] <=3'd0;
                    result_count <=3'd0;
                    done <=1'b0;
                    result_rows[0] <=3'd0; result_rows[1] <=3'd0; result_rows[2] <=3'd0; result_rows[3] <=3'd0;
                    result_rows[4] <=3'd0; result_rows[5] <=3'd0; result_rows[6] <=3'd0; result_rows[7] <=3'd0;
                    result_cols[0] <=3'd0; result_cols[1] <=3'd0; result_cols[2] <=3'd0; result_cols[3] <=3'd0;
                    result_cols[4] <=3'd0; result_cols[5] <=3'd0; result_cols[6] <=3'd0; result_cols[7] <=3'd0;
                end
            end
            SCAN_ROW: begin
                if (row < num_rows) begin
                    col <=3'd0;
                    state <= SCAN_COL;
                end else begin
                    state <= SORT_RESULTS;
                end
            end
            SCAN_COL: begin
                if (col < row_lengths[row]) begin
                    state <= CHECK_MATCH;
                end else begin
                    row <= row +1;
                    col <=3'd0;
                    state <= SCAN_ROW;
                end
            end
            CHECK_MATCH: begin
                if (lst[row][col] == x) begin
                    state <= STORE_MATCH;
                end else begin
                    col <= col +1;
                    state <= SCAN_COL;
                end
            end
            STORE_MATCH: begin
                match_rows[match_count] <= row;
                match_cols[match_count] <= col;
                match_count <= match_count +1;
                col <= col +1;
                state <= SCAN_COL;
            end
            SORT_RESULTS: begin
                result_count <= match_count;
                if (match_count >0) begin
                    result_rows[0] <= match_rows[0];
                    result_cols[0] <= match_cols[0];
                end else begin
                    result_count <=0;
                end
                state <= OUTPUT;
            end
            OUTPUT: begin
                done <=1'b1;
                if (start) begin
                    state <= DONE;
                end
            end
            DONE: begin
                // stay
            end
        endcase
    end
end
endmodule