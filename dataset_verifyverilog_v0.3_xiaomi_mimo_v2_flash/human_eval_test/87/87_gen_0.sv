module find_coordinates (
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
    reg [2:0] row_idx;      // 0 to 7
    reg [2:0] col_idx;      // 7 down to 0
    reg [4:0] match_cnt;    // Internal match count register
    reg [3:0] current_row_len;
    reg [3:0] current_data;
    reg [3:0] i;
    
    // Extract target nibble (lower 4 bits)
    wire [3:0] target_nibble;
    assign target_nibble = target[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match_count <= 5'd0;
            done <= 1'b0;
            row_idx <= 3'd0;
            col_idx <= 3'd7;
            match_cnt <= 5'd0;
            // Initialize output buffer
            for (i = 0; i < 16; i = i + 1) begin
                matches[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match_count <= 5'd0;
                    match_cnt <= 5'd0;
                    row_idx <= 3'd0;
                    col_idx <= 3'd7;
                    // Clear buffer on start
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            matches[i] <= 8'd0;
                        end
                        state <= SCAN;
                    end
                end
                
                SCAN: begin
                    // Extract row length for current row
                    current_row_len <= row_lengths[row_idx * 4 +: 4];
                    
                    // Extract data for current cell
                    // data_lut format: row*32 + col*4 +: 4
                    current_data <= data_lut[row_idx * 32 + col_idx * 4 +: 4];
                    
                    // Check validity and match
                    if (row_valid_mask[row_idx] && (col_idx < current_row_len)) begin
                        if (current_data == target_nibble && match_cnt < 16) begin
                            // Store packed row/col: {row[3:0], col[3:0]}
                            matches[match_cnt] <= {row_idx[3:0], col_idx[3:0]};
                            match_cnt <= match_cnt + 5'd1;
                        end
                    end
                    
                    // Update indices
                    if (col_idx == 3'd0) begin
                        col_idx <= 3'd7;
                        if (row_idx == 3'd7) begin
                            // Finished all cells
                            match_count <= match_cnt;
                            state <= DONE_STATE;
                        end else begin
                            row_idx <= row_idx + 3'd1;
                        end
                    end else begin
                        col_idx <= col_idx - 3'd1;
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

endmodule