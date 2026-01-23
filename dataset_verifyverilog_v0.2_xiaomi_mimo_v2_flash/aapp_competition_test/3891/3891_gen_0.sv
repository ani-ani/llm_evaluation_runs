module black_square_center (
    input clk,
    input rst_n,
    input start,
    input cell_valid,
    input cell_is_black,
    input [7:0] row_index,
    input [7:0] col_index,
    output reg [7:0] center_row,
    output reg [7:0] center_col,
    output reg done
);

    // Parameters for grid size (default 8x8)
    parameter N_ROWS = 8;
    parameter N_COLS = 8;
    parameter TOTAL_CELLS = N_ROWS * N_COLS;

    // State Encoding
    localparam IDLE = 2'b00;
    localparam SCANNING = 2'b01;
    localparam CALCULATING = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Internal Registers
    reg [1:0] current_state, next_state;
    reg [7:0] min_row_reg, max_row_reg;
    reg [7:0] min_col_reg, max_col_reg;
    reg [15:0] cell_count; // Counter for total cells processed
    reg calc_done_reg; // Flag to indicate calculation is finished

    // State Transition Logic (Moore FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = SCANNING;
                else
                    next_state = IDLE;
            end
            SCANNING: begin
                // Transition to CALCULATING when all cells have been processed
                // Note: cell_valid must be high to increment the counter
                if (cell_valid && (cell_count == TOTAL_CELLS - 1))
                    next_state = CALCULATING;
                else
                    next_state = SCANNING;
            end
            CALCULATING: begin
                // One cycle for calculation, then move to DONE
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                // Wait in DONE until reset or new start
                if (start)
                    next_state = SCANNING;
                else
                    next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs and internal registers
            center_row <= 8'b0;
            center_col <= 8'b0;
            done <= 1'b0;
            min_row_reg <= 8'hFF; // Initialize to max possible value
            max_row_reg <= 8'h00; // Initialize to min possible value
            min_col_reg <= 8'hFF;
            max_col_reg <= 8'h00;
            cell_count <= 16'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset counters and trackers when starting new scan
                        min_row_reg <= 8'hFF;
                        max_row_reg <= 8'h00;
                        min_col_reg <= 8'hFF;
                        max_col_reg <= 8'h00;
                        cell_count <= 16'b0;
                    end
                end

                SCANNING: begin
                    if (cell_valid) begin
                        // Increment cell count
                        cell_count <= cell_count + 1;

                        // Update Row Extremes
                        if (cell_is_black) begin
                            if (row_index < min_row_reg)
                                min_row_reg <= row_index;
                            if (row_index > max_row_reg)
                                max_row_reg <= row_index;

                            // Update Col Extremes
                            if (col_index < min_col_reg)
                                min_col_reg <= col_index;
                            if (col_index > max_col_reg)
                                max_col_reg <= col_index;
                        end
                    end
                end

                CALCULATING: begin
                    // Perform arithmetic average and add 1 for 1-based output
                    // (min + max) / 2 is equivalent to (min + max) >> 1
                    center_row <= (min_row_reg + max_row_reg) / 2 + 1;
                    center_col <= (min_col_reg + max_col_reg) / 2 + 1;
                    done <= 1'b0; // Ensure done is low during calculation
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Hold outputs stable until next start
                end
            endcase
        end
    end

endmodule