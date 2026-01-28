module find_black_square (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_packed,
    output reg [3:0] row_center,
    output reg [3:0] col_center,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam M = 8;
    localparam TOTAL = 64;
    localparam IDLE = 2'b00;
    localparam SCANNING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [5:0] idx;
    reg [2:0] min_row;
    reg [2:0] max_row;
    reg [2:0] min_col;
    reg [2:0] max_col;
    reg [5:0] cycle_counter;
    reg [2:0] current_row;
    reg [2:0] current_col;
    reg current_cell;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 6'd0;
            min_row <= 3'd7;
            max_row <= 3'd0;
            min_col <= 3'd7;
            max_col <= 3'd0;
            row_center <= 4'd0;
            col_center <= 4'd0;
            done <= 1'b0;
            cycle_counter <= 6'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            current_cell <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 6'd0;
                    min_row <= 3'd7;
                    max_row <= 3'd0;
                    min_col <= 3'd7;
                    max_col <= 3'd0;
                    cycle_counter <= 6'd0;
                    if (start) begin
                        state <= SCANNING;
                    end
                end

                SCANNING: begin
                    if (idx < TOTAL) begin
                        current_row <= idx[5:3];
                        current_col <= idx[2:0];
                        current_cell <= grid_packed[idx];
                        
                        if (grid_packed[idx]) begin
                            if (idx[5:3] < min_row) min_row <= idx[5:3];
                            if (idx[5:3] > max_row) max_row <= idx[5:3];
                            if (idx[2:0] < min_col) min_col <= idx[2:0];
                            if (idx[2:0] > max_col) max_col <= idx[2:0];
                        end
                        
                        idx <= idx + 6'd1;
                    end
                    
                    cycle_counter <= cycle_counter + 6'd1;
                    
                    if (idx >= TOTAL) begin
                        state <= DONE;
                    end else if (cycle_counter >= 6'd63) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    row_center <= (min_row + max_row) / 2 + 4'd1;
                    col_center <= (min_col + max_col) / 2 + 4'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule