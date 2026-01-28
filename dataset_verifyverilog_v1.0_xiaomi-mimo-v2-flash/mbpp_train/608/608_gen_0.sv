module BellNumberComputation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_ROW = 2'd1;
    localparam [1:0] COMPUTE_COL = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers for state machine
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] i; // row index
    reg [3:0] j; // column index
    reg [3:0] i_max; // stores input n
    reg [3:0] j_max; // stores max column for current row
    reg [7:0] cycle_count; // prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // 2D DP table: 9x9 array of 16-bit values
    reg [15:0] bell [0:8][0:8];
    integer row_idx, col_idx;

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_ROW;
            end
            COMPUTE_ROW: begin
                // If i > i_max (computed up to n) go to DONE
                if (i > i_max) next_state = DONE_STATE;
                else next_state = COMPUTE_COL;
            end
            COMPUTE_COL: begin
                // If computed all columns for this row, go to next row
                if (j > j_max) next_state = COMPUTE_ROW;
                else next_state = COMPUTE_COL;
            end
            DONE_STATE: begin
                next_state = IDLE; // Return to IDLE immediately
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            i_max <= 4'd0;
            j_max <= 4'd0;
            cycle_count <= 8'd0;
            // Reset table
            for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
                for (col_idx = 0; col_idx < 9; col_idx = col_idx + 1) begin
                    bell[row_idx][col_idx] <= 16'd0;
                end
            end
        end else begin
            // Default values
            done <= 1'b0;
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    // Store input n to local register
                    if (start) begin
                        i_max <= n;
                        // Initialize row 0 (Base case)
                        bell[0][0] <= 16'd1;
                    end
                end

                COMPUTE_ROW: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i > i_max) begin
                        // Computation done, result is at bell[n][0]
                        result <= bell[i_max][0];
                    end else begin
                        // Prepare for column computation
                        j <= 4'd0;
                        j_max <= i; // Row i has i+1 columns (0 to i)
                        
                        // Compute bell[i][0] = bell[i-1][i-1]
                        if (i > 4'd0) begin
                            bell[i][0] <= bell[i-1][i-1];
                        end
                    end
                end

                COMPUTE_COL: begin
                    // Compute bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
                    if (j > 4'd0) begin
                        bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
                    end
                    // Move to next column
                    j <= j + 4'd1;
                end

                DONE_STATE: begin
                    done <= 1'b1; // Assert done pulse
                    // Reset will happen in IDLE or next cycle
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State transition
            state <= next_state;
            
            // Update i in COMPUTE_ROW state transition
            if (state == COMPUTE_ROW && i <= i_max) begin
                i <= i + 4'd1;
            end
        end
    end

endmodule