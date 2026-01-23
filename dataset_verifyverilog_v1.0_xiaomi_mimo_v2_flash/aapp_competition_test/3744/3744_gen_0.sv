module team_selection (
    input clk, rst_n, start,
    input [3:0] n, p, s,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [15:0] total,
    output reg [7:0] prog_indices [0:7],
    output reg [7:0] sports_indices [0:7],
    output reg [3:0] prog_count,
    output reg [3:0] sports_count,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] SORT_A = 3'd1;
localparam [2:0] CALC_CONV = 3'd2;
localparam [2:0] SELECT_TEAMS = 3'd3;
localparam [2:0] CALC_TOTAL = 3'd4;
localparam [2:0] DONE = 3'd5;

// Internal state
reg [2:0] state;
reg [7:0] temp_a [0:7];
reg [7:0] temp_b [0:7];
reg [7:0] conversion [0:7];
reg [3:0] i_reg, j_reg, k_reg;
reg [15:0] current_sum;
reg [2:0] conv_idx;
reg [2:0] prog_idx_counter;
reg [2:0] sports_idx_counter;
reg [2:0] temp_idx;
reg [2:0] current_idx;

// Loop counters for combinational logic
integer loop_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        total <= 16'd0;
        prog_count <= 4'd0;
        sports_count <= 4'd0;
        current_sum <= 16'd0;
        i_reg <= 3'd0;
        j_reg <= 3'd0;
        k_reg <= 3'd0;
        conv_idx <= 3'd0;
        prog_idx_counter <= 3'd0;
        sports_idx_counter <= 3'd0;
        temp_idx <= 3'd0;
        current_idx <= 3'd0;
        // Initialize output arrays
        for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
            prog_indices[loop_idx] <= 8'd0;
            sports_indices[loop_idx] <= 8'd0;
            temp_a[loop_idx] <= 8'd0;
            temp_b[loop_idx] <= 8'd0;
            conversion[loop_idx] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                current_sum <= 16'd0;
                prog_idx_counter <= 3'd0;
                sports_idx_counter <= 3'd0;
                temp_idx <= 3'd0;
                current_idx <= 3'd0;
                // Initialize output arrays
                for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                    prog_indices[loop_idx] <= 8'd0;
                    sports_indices[loop_idx] <= 8'd0;
                end
                if (start && n > 4'd0) begin
                    // Copy inputs to temp arrays
                    for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                        if (loop_idx < n) begin
                            temp_a[loop_idx] <= a[loop_idx];
                            temp_b[loop_idx] <= b[loop_idx];
                        end else begin
                            temp_a[loop_idx] <= 8'd0;
                            temp_b[loop_idx] <= 8'd0;
                        end
                    end
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                    state <= SORT_A;
                end
            end
            
            SORT_A: begin
                // Bubble sort descending for temp_a
                if (i_reg < n - 3'd1) begin
                    if (j_reg < n - i_reg - 3'd1) begin
                        if (temp_a[j_reg] < temp_a[j_reg + 3'd1]) begin
                            // Swap a
                            temp_a[j_reg] <= temp_a[j_reg + 3'd1];
                            temp_a[j_reg + 3'd1] <= temp_a[j_reg];
                            // Swap b
                            temp_b[j_reg] <= temp_b[j_reg + 3'd1];
                            temp_b[j_reg + 3'd1] <= temp_b[j_reg];
                        end
                        j_reg <= j_reg + 3'd1;
                    end else begin
                        j_reg <= 3'd0;
                        i_reg <= i_reg + 3'd1;
                    end
                end else begin
                    i_reg <= 3'd0;
                    state <= CALC_CONV;
                end
            end
            
            CALC_CONV: begin
                // Calculate conversion gains
                if (i_reg < n) begin
                    // temp_b - temp_a
                    conversion[i_reg] <= temp_b[i_reg] - temp_a[i_reg];
                    i_reg <= i_reg + 3'd1;
                end else begin
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                    state <= SELECT_TEAMS;
                end
            end
            
            SELECT_TEAMS: begin
                // Select programming team (top p based on a, already sorted)
                if (prog_idx_counter < p && prog_idx_counter < n) begin
                    if (prog_idx_counter < p) begin
                        prog_indices[prog_idx_counter] <= prog_idx_counter;
                        prog_idx_counter <= prog_idx_counter + 3'd1;
                    end
                end else if (sports_idx_counter < s && sports_idx_counter < n) begin
                    // For sports, consider conversion gains
                    // Strategy: pick best conversions from top p+s students
                    if (current_idx < n && current_idx < p + s) begin
                        // Check if this student is already in programming
                        reg already_in_prog;
                        already_in_prog = 1'b0;
                        for (integer k = 0; k < 8; k = k + 1) begin
                            if (k < prog_idx_counter && prog_indices[k] == current_idx) begin
                                already_in_prog = 1'b1;
                            end
                        end
                        
                        if (!already_in_prog) begin
                            sports_indices[sports_idx_counter] <= current_idx;
                            sports_idx_counter <= sports_idx_counter + 3'd1;
                        end
                        current_idx <= current_idx + 3'd1;
                    end else if (current_idx >= p + s && sports_idx_counter < s) begin
                        // Fill remaining sports slots with next available students
                        if (current_idx < n) begin
                            sports_indices[sports_idx_counter] <= current_idx;
                            sports_idx_counter <= sports_idx_counter + 3'd1;
                            current_idx <= current_idx + 3'd1;
                        end else begin
                            state <= CALC_TOTAL;
                        end
                    end else begin
                        state <= CALC_TOTAL;
                    end
                end else begin
                    state <= CALC_TOTAL;
                end
            end
            
            CALC_TOTAL: begin
                // Calculate total strength
                current_sum <= 16'd0;
                conv_idx <= 3'd0;
                state <= DONE;
            end
            
            DONE: begin
                // Accumulate sum
                if (conv_idx < prog_idx_counter) begin
                    current_sum <= current_sum + {8'd0, temp_a[prog_indices[conv_idx]]};
                    conv_idx <= conv_idx + 3'd1;
                end else if (conv_idx < prog_idx_counter + sports_idx_counter) begin
                    current_sum <= current_sum + {8'd0, temp_b[sports_indices[conv_idx - prog_idx_counter]]};
                    conv_idx <= conv_idx + 3'd1;
                end else begin
                    total <= current_sum;
                    prog_count <= {1'b0, prog_idx_counter};
                    sports_count <= {1'b0, sports_idx_counter};
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule