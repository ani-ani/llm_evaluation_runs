module king_spread_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] board_flat,
    output reg [15:0] mirko_spread,
    output reg [15:0] slavko_spread,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] CALC_M = 3'd2;
    localparam [2:0] CALC_S = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State register
    reg [2:0] state, next_state;

    // Coordinate storage for pieces
    reg [3:0] mirko_coords_row [0:7];
    reg [3:0] mirko_coords_col [0:7];
    reg [3:0] slavko_coords_row [0:7];
    reg [3:0] slavko_coords_col [0:7];

    // Piece counters
    reg [2:0] mirko_count;
    reg [2:0] slavko_count;

    // Scan counter
    reg [7:0] scan_index;

    // Calculation counters
    reg [2:0] calc_i;
    reg [2:0] calc_j;

    // Accumulators
    reg [15:0] mirko_accum;
    reg [15:0] slavko_accum;

    // Temporary registers for calculation
    reg [3:0] temp_row1, temp_row2;
    reg [3:0] temp_col1, temp_col2;
    reg [3:0] temp_row_diff, temp_col_diff;
    reg [3:0] temp_chebyshev;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Clear coordinate arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                mirko_coords_row[i] <= 4'd0;
                mirko_coords_col[i] <= 4'd0;
                slavko_coords_row[i] <= 4'd0;
                slavko_coords_col[i] <= 4'd0;
            end
            
            // Clear counters
            mirko_count <= 3'd0;
            slavko_count <= 3'd0;
            scan_index <= 8'd0;
            calc_i <= 3'd0;
            calc_j <= 3'd0;
            
            // Clear accumulators
            mirko_accum <= 16'd0;
            slavko_accum <= 16'd0;
            
            // Clear outputs
            mirko_spread <= 16'd0;
            slavko_spread <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = SCAN;
                end else begin
                    next_state = IDLE;
                end
            end

            SCAN: begin
                done = 1'b0;
                // Parse board_flat
                if (scan_index < 8'd255) begin
                    next_state = SCAN;
                end else begin
                    next_state = CALC_M;
                end
            end

            CALC_M: begin
                done = 1'b0;
                // Calculate Mirko spread
                if (calc_i < mirko_count - 1) begin
                    if (calc_j < mirko_count - 1) begin
                        next_state = CALC_M;
                    end else begin
                        next_state = CALC_M;
                    end
                end else begin
                    next_state = CALC_S;
                end
            end

            CALC_S: begin
                done = 1'b0;
                // Calculate Slavko spread
                if (calc_i < slavko_count - 1) begin
                    if (calc_j < slavko_count - 1) begin
                        next_state = CALC_S;
                    end else begin
                        next_state = CALC_S;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Scan logic
    always @(posedge clk) begin
        if (state == SCAN && scan_index < 8'd255) begin
            // Extract current cell value
            reg [1:0] cell_value;
            cell_value = board_flat[(scan_index * 2) + 1 : scan_index * 2];
            
            // Calculate row and column
            reg [3:0] current_row;
            reg [3:0] current_col;
            current_row = scan_index[7:4];
            current_col = scan_index[3:0];
            
            // Store coordinates based on cell value
            if (cell_value == 2'd1 && mirko_count < 8) begin
                mirko_coords_row[mirko_count] = current_row;
                mirko_coords_col[mirko_count] = current_col;
                mirko_count = mirko_count + 1;
            end else if (cell_value == 2'd2 && slavko_count < 8) begin
                slavko_coords_row[slavko_count] = current_row;
                slavko_coords_col[slavko_count] = current_col;
                slavko_count = slavko_count + 1;
            end
            
            scan_index = scan_index + 1;
        end
    end

    // Mirko calculation logic
    always @(posedge clk) begin
        if (state == CALC_M) begin
            if (calc_i < mirko_count - 1) begin
                if (calc_j < mirko_count - 1) begin
                    // Calculate Chebyshev distance
                    temp_row1 = mirko_coords_row[calc_i];
                    temp_col1 = mirko_coords_col[calc_i];
                    temp_row2 = mirko_coords_row[calc_j];
                    temp_col2 = mirko_coords_col[calc_j];
                    
                    temp_row_diff = (temp_row1 > temp_row2) ? (temp_row1 - temp_row2) : (temp_row2 - temp_row1);
                    temp_col_diff = (temp_col1 > temp_col2) ? (temp_col1 - temp_col2) : (temp_col2 - temp_col1);
                    
                    temp_chebyshev = (temp_row_diff > temp_col_diff) ? temp_row_diff : temp_col_diff;
                    
                    mirko_accum = mirko_accum + temp_chebyshev;
                    
                    calc_j = calc_j + 1;
                end else begin
                    calc_j = calc_i + 1;
                    calc_i = calc_i + 1;
                end
            end else begin
                mirko_spread = mirko_accum;
                calc_i = 0;
                calc_j = 1;
            end
        end
    end

    // Slavko calculation logic
    always @(posedge clk) begin
        if (state == CALC_S) begin
            if (calc_i < slavko_count - 1) begin
                if (calc_j < slavko_count - 1) begin
                    // Calculate Chebyshev distance
                    temp_row1 = slavko_coords_row[calc_i];
                    temp_col1 = slavko_coords_col[calc_i];
                    temp_row2 = slavko_coords_row[calc_j];
                    temp_col2 = slavko_coords_col[calc_j];
                    
                    temp_row_diff = (temp_row1 > temp_row2) ? (temp_row1 - temp_row2) : (temp_row2 - temp_row1);
                    temp_col_diff = (temp_col1 > temp_col2) ? (temp_col1 - temp_col2) : (temp_col2 - temp_col1);
                    
                    temp_chebyshev = (temp_row_diff > temp_col_diff) ? temp_row_diff : temp_col_diff;
                    
                    slavko_accum = slavko_accum + temp_chebyshev;
                    
                    calc_j = calc_j + 1;
                end else begin
                    calc_j = calc_i + 1;
                    calc_i = calc_i + 1;
                end
            end else begin
                slavko_spread = slavko_accum;
                calc_i = 0;
                calc_j = 1;
            end
        end
    end

    // Done signal generation
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule