module top(
    input clk,
    input rst_n,
    input start,
    input [5:0] R,
    input [5:0] C,
    input [31:0] K,
    input [7:0] grid_row [0:49],
    input [31:0] score [0:49],
    output reg [63:0] result,
    output reg done
);
    
    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] READ_GRID = 3'b001;
    localparam [2:0] SIMULATE_PART = 3'b010;
    localparam [2:0] CHECK_CYCLE = 3'b011;
    localparam [2:0] COMPUTE_RESULT = 3'b100;
    
    reg [2:0] state = IDLE;
    reg [5:0] row_counter = 0;
    reg [5:0] col_counter = 0;
    reg [5:0] part_counter = 0;
    reg [31:0] cycle_start = 0;
    reg [31:0] cycle_length = 0;
    reg [63:0] total_score = 0;
    reg [63:0] current_score = 0;
    reg [63:0] prev_score = 0;
    reg [63:0] cycle_scores [0:1023];
    reg [31:0] cycle_index = 0;
    reg [31:0] cycle_count = 0;
    reg [31:0] remaining_parts = 0;
    reg [31:0] cycle_detected = 0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_counter <= 0;
            col_counter <= 0;
            part_counter <= 0;
            cycle_start <= 0;
            cycle_length <= 0;
            total_score <= 0;
            current_score <= 0;
            prev_score <= 0;
            cycle_index <= 0;
            cycle_count <= 0;
            remaining_parts <= 0;
            cycle_detected <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READ_GRID;
                        row_counter <= 0;
                        col_counter <= 0;
                    end
                end
                READ_GRID: begin
                    if (row_counter < R) begin
                        if (col_counter < C) begin
                            // Process grid cell
                            col_counter <= col_counter + 1;
                        end else begin
                            col_counter <= 0;
                            row_counter <= row_counter + 1;
                        end
                    end else begin
                        state <= SIMULATE_PART;
                        part_counter <= 0;
                    end
                end
                SIMULATE_PART: begin
                    if (part_counter < K) begin
                        // Simulate one part
                        // Update current_score based on grid and score
                        // This is a placeholder for the actual DP computation
                        current_score <= current_score + score[col_counter];
                        
                        // Check for cycle detection
                        if (part_counter > 1 && current_score == prev_score) begin
                            cycle_start <= part_counter - 1;
                            cycle_length <= 1;
                            cycle_detected <= 1;
                            state <= CHECK_CYCLE;
                        end else begin
                            prev_score <= current_score;
                            part_counter <= part_counter + 1;
                        end
                    end else begin
                        state <= COMPUTE_RESULT;
                    end
                end
                CHECK_CYCLE: begin
                    if (cycle_detected) begin
                        // Compute remaining parts after cycle detection
                        remaining_parts <= K - cycle_start;
                        cycle_count <= remaining_parts / cycle_length;
                        state <= COMPUTE_RESULT;
                    end else begin
                        state <= SIMULATE_PART;
                    end
                end
                COMPUTE_RESULT: begin
                    if (cycle_detected) begin
                        total_score <= current_score * cycle_count;
                    end else begin
                        total_score <= current_score;
                    end
                    result <= total_score;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module part_simulator(
    input clk,
    input rst_n,
    input [5:0] R,
    input [5:0] C,
    input [7:0] grid_cell,
    input [31:0] cell_score,
    input valid_in,
    output reg [63:0] max_score_out,
    output reg valid_out
);
    
    reg [5:0] row = 0;
    reg [5:0] col = 0;
    reg [63:0] dp [0:49][0:49];
    reg [63:0] current_max = 0;
    reg [63:0] temp_score = 0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 0;
            col <= 0;
            max_score_out <= 0;
            valid_out <= 0;
            for (int i = 0; i < 50; i++) begin
                for (int j = 0; j < 50; j++) begin
                    dp[i][j] <= 0;
                end
            end
        end else begin
            if (valid_in) begin
                if (row == R) begin
                    // Bottom row initialization
                    dp[row][col] <= cell_score;
                end else begin
                    // Update DP based on grid cell
                    case (grid_cell)
                        8'b0: begin // '.'
                            dp[row][col] <= dp[row + 1][col];
                        end
                        8'b88: begin // 'X'
                            dp[row][col] <= 0;
                        end
                        8'b76: begin // 'L'
                            if (col > 0) begin
                                dp[row][col] <= dp[row][col - 1];
                            end else begin
                                dp[row][col] <= 0;
                            end
                        end
                        8'b82: begin // 'R'
                            if (col < C - 1) begin
                                dp[row][col] <= dp[row][col + 1];
                            end else begin
                                dp[row][col] <= 0;
                            end
                        end
                        8'b63: begin // '?'
                            temp_score <= 0;
                            if (col > 0) begin
                                temp_score <= dp[row][col - 1];
                            end
                            if (col < C - 1 && dp[row][col + 1] > temp_score) begin
                                temp_score <= dp[row][col + 1];
                            end
                            dp[row][col] <= temp_score;
                        end
                    endcase
                end
                
                // Move to next cell
                if (col == C - 1) begin
                    col <= 0;
                    if (row == 0) begin
                        // Compute max score for the part
                        current_max <= 0;
                        for (int j = 0; j < C; j++) begin
                            if (dp[0][j] > current_max) begin
                                current_max <= dp[0][j];
                            end
                        end
                        max_score_out <= current_max;
                        valid_out <= 1;
                        row <= R;
                    end else begin
                        row <= row - 1;
                    end
                end else begin
                    col <= col + 1;
                end
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule