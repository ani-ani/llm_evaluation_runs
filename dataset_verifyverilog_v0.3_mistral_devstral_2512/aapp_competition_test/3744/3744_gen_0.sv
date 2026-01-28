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

// Internal state
reg [2:0] state;
reg [7:0] temp_a [0:7];
reg [7:0] temp_b [0:7];
reg [2:0] i, j, k;
reg [15:0] current_sum;
reg [7:0] conversion [0:7];

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] SORT_A = 3'd1;
localparam [2:0] CALC_CONV = 3'd2;
localparam [2:0] SELECT_TEAMS = 3'd3;
localparam [2:0] CALC_TOTAL = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        total <= 16'd0;
        prog_count <= 4'd0;
        sports_count <= 4'd0;
        for (integer idx = 0; idx < 8; idx = idx + 1) begin
            prog_indices[idx] <= 8'd0;
            sports_indices[idx] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Copy inputs to temp arrays
                    for (integer idx = 0; idx < 8; idx = idx + 1) begin
                        temp_a[idx] <= (idx < n) ? a[idx] : 8'd0;
                        temp_b[idx] <= (idx < n) ? b[idx] : 8'd0;
                    end
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                    state <= SORT_A;
                end
            end
            
            SORT_A: begin
                // Simple bubble sort for a values (max 8 elements)
                if (i < n - 1) begin
                    if (j < n - 1 - i) begin
                        if (temp_a[j] < temp_a[j+1]) begin
                            // Swap a
                            temp_a[j] <= temp_a[j+1];
                            temp_a[j+1] <= temp_a[j];
                            // Swap b accordingly
                            temp_b[j] <= temp_b[j+1];
                            temp_b[j+1] <= temp_b[j];
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        i <= i + 3'd1;
                    end
                end else begin
                    i <= 3'd0;
                    state <= CALC_CONV;
                end
            end
            
            CALC_CONV: begin
                // Calculate conversion gains (b - a)
                if (i < n) begin
                    conversion[i] <= temp_b[i] - temp_a[i];
                    i <= i + 3'd1;
                end else begin
                    i <= 3'd0;
                    j <= 3'd0;
                    state <= SELECT_TEAMS;
                end
            end
            
            SELECT_TEAMS: begin
                // Select top p for programming (based on a)
                // Then consider conversions for sports
                if (i < p) begin
                    prog_indices[i] <= i;
                    i <= i + 3'd1;
                end else if (i < p + s) begin
                    // For sports, consider conversion gains from top p+s students
                    // Find best conversions
                    if (j < n && j < p + s) begin
                        if (j < p) begin
                            // Already in programming, consider converting to sports
                            // Check if better than current sports selection
                            sports_indices[i - p] <= j;
                        end else begin
                            // Add directly to sports
                            sports_indices[i - p] <= j;
                        end
                        j <= j + 3'd1;
                        i <= i + 3'd1;
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
                for (integer idx = 0; idx < 8; idx = idx + 1) begin
                    if (prog_indices[idx] < n && idx < p) begin
                        current_sum <= current_sum + temp_a[prog_indices[idx]];
                    end
                    if (sports_indices[idx] < n && idx < s) begin
                        current_sum <= current_sum + temp_b[sports_indices[idx]];
                    end
                end
                prog_count <= p;
                sports_count <= s;
                state <= DONE_STATE;
            end
            
            DONE_STATE: begin
                total <= current_sum;
                done <= 1'b1;
                // Wait for reset
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule