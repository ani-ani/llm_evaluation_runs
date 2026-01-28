module spaceship_destroyer(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] group1_0,
    input signed [7:0] group1_1,
    input signed [7:0] group2_0,
    input signed [7:0] group2_1,
    input [1:0] n,
    input [1:0] m,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PREPARE_SUMS = 2'd1;
    localparam [1:0] ITERATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state;
    reg signed [7:0] g1_0, g1_1;
    reg signed [7:0] g2_0, g2_1;
    reg signed [7:0] sums [0:3];
    reg [1:0] i, j;
    reg [7:0] best;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i <= 2'd0;
            j <= 2'd0;
            best <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        g1_0 <= group1_0;
                        g1_1 <= group1_1;
                        g2_0 <= group2_0;
                        g2_1 <= group2_1;
                        state <= PREPARE_SUMS;
                    end
                end

                PREPARE_SUMS: begin
                    // Compute sums based on n and m
                    sums[0] <= (n >= 1 && m >= 1) ? g1_0 + g2_0 : 8'sd0;
                    sums[1] <= (n >= 1 && m >= 2) ? g1_0 + g2_1 : 8'sd0;
                    sums[2] <= (n >= 2 && m >= 1) ? g1_1 + g2_0 : 8'sd0;
                    sums[3] <= (n >= 2 && m >= 2) ? g1_1 + g2_1 : 8'sd0;
                    i <= 2'd0;
                    j <= 2'd0;
                    best <= 8'd0;
                    cycle_count <= 8'd0;
                    state <= ITERATE;
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute destruction for current pair (i,j)
                    reg bit0_group1, bit1_group1, bit0_group2, bit1_group2;
                    reg [7:0] total;
                    
                    // Group1 ship0
                    bit0_group1 = (n >= 1) && (
                        (sums[i] - g1_0 == g2_0) ||
                        (sums[i] - g1_0 == g2_1) ||
                        (sums[j] - g1_0 == g2_0) ||
                        (sums[j] - g1_0 == g2_1)
                    );
                    
                    // Group1 ship1
                    bit1_group1 = (n >= 2) && (
                        (sums[i] - g1_1 == g2_0) ||
                        (sums[i] - g1_1 == g2_1) ||
                        (sums[j] - g1_1 == g2_0) ||
                        (sums[j] - g1_1 == g2_1)
                    );
                    
                    // Group2 ship0
                    bit0_group2 = (m >= 1) && (
                        (sums[i] - g2_0 == g1_0) ||
                        (sums[i] - g2_0 == g1_1) ||
                        (sums[j] - g2_0 == g1_0) ||
                        (sums[j] - g2_0 == g1_1)
                    );
                    
                    // Group2 ship1
                    bit1_group2 = (m >= 2) && (
                        (sums[i] - g2_1 == g1_0) ||
                        (sums[i] - g2_1 == g1_1) ||
                        (sums[j] - g2_1 == g1_0) ||
                        (sums[j] - g2_1 == g1_1)
                    );
                    
                    total = bit0_group1 + bit1_group1 + bit0_group2 + bit1_group2;
                    if (total > best) begin
                        best <= total;
                    end
                    
                    // Update indices
                    if (j < 3) begin
                        j <= j + 1;
                    end else begin
                        j <= 2'd0;
                        if (i < 3) begin
                            i <= i + 1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= best;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule