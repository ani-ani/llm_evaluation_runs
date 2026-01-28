module tree_avg_dist (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [63:0] dist_matrix,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_SUM  = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] CONVERT   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [15:0] dist_sum;
    reg [7:0] divisor;
    reg [15:0] temp_result;
    reg [7:0] current_dist;
    reg [3:0] n_reg;

    // State transition and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            dist_sum <= 16'd0;
            divisor <= 8'd0;
            temp_result <= 16'd0;
            current_dist <= 8'd0;
            n_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    dist_sum <= 16'd0;
                    if (start) begin
                        n_reg <= n;
                        state <= CALC_SUM;
                    end
                end

                CALC_SUM: begin
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (i != j) begin
                                // Extract dist_matrix[i*64 + j*8 +: 8]
                                current_dist <= dist_matrix[(i*64) + (j*8) +: 8];
                                dist_sum <= dist_sum + dist_matrix[(i*64) + (j*8) +: 8];
                            end
                            if (j == n_reg - 4'd1) begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end else begin
                                j <= j + 4'd1;
                            end
                        end
                    end else begin
                        // Calculate divisor = n*(n-1)/2
                        divisor <= (n_reg * (n_reg - 4'd1)) >> 1;
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (divisor != 8'd0) begin
                        // Convert to Q8.8: (dist_sum << 8) / divisor
                        temp_result <= (dist_sum << 8) / divisor;
                    end else begin
                        temp_result <= 16'd0;
                    end
                    state <= CONVERT;
                end

                CONVERT: begin
                    result <= temp_result;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule