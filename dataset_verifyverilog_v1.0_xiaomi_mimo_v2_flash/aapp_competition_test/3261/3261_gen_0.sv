module zigzag_grey_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] K,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Grid constants
    localparam [3:0] ROWS = 4'd4;
    localparam [3:0] COLS = 4'd4;
    localparam [7:0] MAX_CELLS = 8'd16;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] counter;
    reg [7:0] cycle_count;
    reg [3:0] diag;      // Current diagonal (0 to 6)
    reg [3:0] row_pos;
    reg [3:0] col_pos;
    reg [3:0] diag_len;
    reg [3:0] current_idx; // Position within diagonal
    reg is_even_diag;
    reg is_last_cell;

    // Helper signals
    wire grey_condition;
    wire [3:0] row_val;
    wire [3:0] col_val;

    assign row_val = row_pos;
    assign col_val = col_pos;
    assign grey_condition = (row_val & col_val) == 4'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 16'd0;
            cycle_count <= 8'd0;
            diag <= 4'd0;
            row_pos <= 4'd0;
            col_pos <= 4'd0;
            diag_len <= 4'd0;
            current_idx <= 4'd0;
            is_even_diag <= 1'b1;
            is_last_cell <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 16'd0;
                    cycle_count <= 8'd0;
                    diag <= 4'd0;
                    row_pos <= 4'd0;
                    col_pos <= 4'd0;
                    current_idx <= 4'd0;
                    is_even_diag <= 1'b1;
                    is_last_cell <= 1'b0;
                    
                    if (start) begin
                        state <= PROCESS;
                        // Initialize first cell (0,0)
                        row_pos <= 4'd0;
                        col_pos <= 4'd0;
                        diag <= 4'd0;
                        diag_len <= 4'd1;
                        current_idx <= 4'd0;
                        is_even_diag <= 1'b1;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if cell is grey and within bounds
                    if (grey_condition && (row_pos < ROWS) && (col_pos < COLS)) begin
                        result <= result + 16'd1;
                    end
                    
                    counter <= counter + 16'd1;
                    
                    // Check if we've visited K cells
                    if (counter >= (K - 16'd1)) begin
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Calculate next cell in zigzag pattern
                        if (current_idx < (diag_len - 4'd1)) begin
                            // Move within current diagonal
                            current_idx <= current_idx + 4'd1;
                            if (is_even_diag) begin
                                // Even diagonal: down-left (row++, col--)
                                row_pos <= row_pos + 4'd1;
                                col_pos <= col_pos - 4'd1;
                            end else begin
                                // Odd diagonal: up-right (row--, col++)
                                row_pos <= row_pos - 4'd1;
                                col_pos <= col_pos + 4'd1;
                            end
                        end else begin
                            // Move to next diagonal
                            diag <= diag + 4'd1;
                            current_idx <= 4'd0;
                            is_even_diag <= ~is_even_diag;
                            
                            if (is_even_diag) begin
                                // Moving from even diagonal
                                if (col_pos < (COLS - 4'd1)) begin
                                    col_pos <= col_pos + 4'd1;
                                end else begin
                                    row_pos <= row_pos + 4'd1;
                                end
                            end else begin
                                // Moving from odd diagonal
                                if (row_pos < (ROWS - 4'd1)) begin
                                    row_pos <= row_pos + 4'd1;
                                end else begin
                                    col_pos <= col_pos + 4'd1;
                                end
                            end
                            
                            // Calculate new diagonal length
                            diag <= diag + 4'd1;
                            if (diag + 4'd1 < 4'd4) begin
                                diag_len <= diag + 4'd2;
                            end else begin
                                // On longer side (max 4 for 4x4)
                                if (diag + 4'd1 == 4'd4) begin
                                    diag_len <= 4'd4;
                                end else begin
                                    // Decreasing: 7,6,5,4,3,2,1
                                    diag_len <= 4'd8 - (diag + 4'd1);
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule