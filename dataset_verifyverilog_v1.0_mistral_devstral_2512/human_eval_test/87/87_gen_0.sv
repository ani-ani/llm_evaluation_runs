module find_coordinates(
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0] row_valid_mask,
    input [31:0] row_lengths,
    input [255:0] data_lut,
    output reg [4:0] match_count,
    output reg [7:0] matches [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [2:0] row_idx;
    reg [2:0] col_idx;
    reg [4:0] match_count_reg;
    reg [7:0] current_row_length;
    reg [3:0] current_data;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            match_count <= 5'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                matches[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SCAN;
                        row_idx <= 3'd0;
                        col_idx <= 3'd7;
                        match_count <= 5'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            matches[i] <= 8'd0;
                        end
                    end
                end

                SCAN: begin
                    current_row_length <= row_lengths[row_idx*4 +: 4];
                    current_data <= data_lut[row_idx*32 + col_idx*4 +: 4];

                    if (row_valid_mask[row_idx] && col_idx < current_row_length && current_data == target[3:0] && match_count < 16) begin
                        matches[match_count] <= {row_idx, col_idx};
                        match_count <= match_count + 1;
                    end

                    if (col_idx == 0) begin
                        col_idx <= 3'd7;
                        if (row_idx == 7) begin
                            state <= DONE_STATE;
                        end else begin
                            row_idx <= row_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx - 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign match_count = match_count_reg;

endmodule