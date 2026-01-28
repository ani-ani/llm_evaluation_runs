module spaceship_destroyer (
    input clk, rst_n, start,
    input signed [7:0] group1_0, group1_1,
    input signed [7:0] group2_0, group2_1,
    input [1:0] n, m,
    output reg [7:0] result,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] PREPARE_SUMS = 2'd1;
localparam [1:0] ITERATE = 2'd2;
localparam [1:0] DONE_STATE = 2'd3;

// Internal registers
reg signed [7:0] g1_0_reg, g1_1_reg;
reg signed [7:0] g2_0_reg, g2_1_reg;
reg signed [7:0] sums [0:3];
reg [1:0] i_reg, j_reg;
reg [7:0] best_reg;
reg [1:0] state;

// Combinational signals for iteration logic
reg signed [7:0] sums_i, sums_j;
reg bit0_group1, bit1_group1;
reg bit0_group2, bit1_group2;
reg [2:0] total;
reg [7:0] best_next;

// Helper signals to check ship existence
reg ship1_g1_exists, ship2_g1_exists;
reg ship1_g2_exists, ship2_g2_exists;

// Cycle counter to prevent infinite loops
reg [3:0] cycle_counter;
localparam [3:0] MAX_CYCLES = 4'd12;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 8'd0;
        g1_0_reg <= 8'sd0;
        g1_1_reg <= 8'sd0;
        g2_0_reg <= 8'sd0;
        g2_1_reg <= 8'sd0;
        sums[0] <= 8'sd0;
        sums[1] <= 8'sd0;
        sums[2] <= 8'sd0;
        sums[3] <= 8'sd0;
        i_reg <= 2'd0;
        j_reg <= 2'd0;
        best_reg <= 8'd0;
        cycle_counter <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 4'd0;
                if (start) begin
                    // Load inputs into registers
                    g1_0_reg <= group1_0;
                    g1_1_reg <= group1_1;
                    g2_0_reg <= group2_0;
                    g2_1_reg <= group2_1;
                    state <= PREPARE_SUMS;
                end
            end

            PREPARE_SUMS: begin
                // Initialize arrays and counters
                i_reg <= 2'd0;
                j_reg <= 2'd0;
                best_reg <= 8'd0;
                cycle_counter <= 4'd0;
                
                // Compute all possible sums based on n and m
                sums[0] <= (n >= 2'd1 && m >= 2'd1) ? g1_0_reg + g2_0_reg : 8'sd0;
                sums[1] <= (n >= 2'd1 && m >= 2'd2) ? g1_0_reg + g2_1_reg : 8'sd0;
                sums[2] <= (n >= 2'd2 && m >= 2'd1) ? g1_1_reg + g2_0_reg : 8'sd0;
                sums[3] <= (n >= 2'd2 && m >= 2'd2) ? g1_1_reg + g2_1_reg : 8'sd0;
                
                state <= ITERATE;
            end

            ITERATE: begin
                cycle_counter <= cycle_counter + 4'd1;
                
                // Check which ships exist
                ship1_g1_exists = (n >= 2'd1);
                ship2_g1_exists = (n >= 2'd2);
                ship1_g2_exists = (m >= 2'd1);
                ship2_g2_exists = (m >= 2'd2);
                
                // Get sums for current indices (avoid array slice assignment)
                case (i_reg)
                    2'd0: sums_i = sums[0];
                    2'd1: sums_i = sums[1];
                    2'd2: sums_i = sums[2];
                    2'd3: sums_i = sums[3];
                    default: sums_i = sums[0];
                endcase
                
                case (j_reg)
                    2'd0: sums_j = sums[0];
                    2'd1: sums_j = sums[1];
                    2'd2: sums_j = sums[2];
                    2'd3: sums_j = sums[3];
                    default: sums_j = sums[0];
                endcase
                
                // Compute destruction bits for Group1 ships
                bit0_group1 = ship1_g1_exists && (
                    (sums_i - g1_0_reg == g2_0_reg) ||
                    (sums_i - g1_0_reg == g2_1_reg) ||
                    (sums_j - g1_0_reg == g2_0_reg) ||
                    (sums_j - g1_0_reg == g2_1_reg)
                );
                
                bit1_group1 = ship2_g1_exists && (
                    (sums_i - g1_1_reg == g2_0_reg) ||
                    (sums_i - g1_1_reg == g2_1_reg) ||
                    (sums_j - g1_1_reg == g2_0_reg) ||
                    (sums_j - g1_1_reg == g2_1_reg)
                );
                
                // Compute destruction bits for Group2 ships
                bit0_group2 = ship1_g2_exists && (
                    (sums_i - g2_0_reg == g1_0_reg) ||
                    (sums_i - g2_0_reg == g1_1_reg) ||
                    (sums_j - g2_0_reg == g1_0_reg) ||
                    (sums_j - g2_0_reg == g1_1_reg)
                );
                
                bit1_group2 = ship2_g2_exists && (
                    (sums_i - g2_1_reg == g1_0_reg) ||
                    (sums_i - g2_1_reg == g1_1_reg) ||
                    (sums_j - g2_1_reg == g1_0_reg) ||
                    (sums_j - g2_1_reg == g1_1_reg)
                );
                
                // Sum total destroyed
                total = bit0_group1 + bit1_group1 + bit0_group2 + bit1_group2;
                best_next = (total > best_reg) ? total : best_reg;
                best_reg <= best_next;
                
                // Update indices
                if (j_reg < 2'd3) begin
                    j_reg <= j_reg + 2'd1;
                end else begin
                    j_reg <= 2'd0;
                    if (i_reg < 2'd3) begin
                        i_reg <= i_reg + 2'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                // Safety timeout
                if (cycle_counter >= MAX_CYCLES) begin
                    state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                result <= best_reg;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule