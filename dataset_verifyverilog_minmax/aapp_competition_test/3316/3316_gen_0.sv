module lottery_probability (
    input clk,
    input rst_n,
    input start,
    input [4:0] m,
    input [3:0] n,
    input [3:0] t,
    input [4:0] p,
    output reg [31:0] probability,
    output reg done
);

    // State definitions
    parameter IDLE = 2'b00;
    parameter CALC_COMB = 2'b01;
    parameter DIVIDE = 2'b10;
    parameter DONE = 2'b11;

    // State machine registers
    reg [1:0] state;
    reg [4:0] cycle_count;
    reg [4:0] k_min, max_k;
    reg [4:0] current_k;
    reg [31:0] accumulator;
    reg [13:0] denominator;
    reg [50:0] remainder_div; // 51-bit for 3-bit shifts
    reg [31:0] quotient;
    reg [3:0] div_cycle_count;

    // Combination lookup table: C[n][k] for n,k in [0,16]
    reg [31:0] comb_table [0:16][0:16];
    integer i, j;

    // Precompute combination values
    initial begin
        for (i = 0; i <= 16; i++) begin
            for (j = 0; j <= i; j++) begin
                if (j == 0 || j == i) comb_table[i][j] = 1;
                else comb_table[i][j] = comb_table[i-1][j-1] + comb_table[i-1][j];
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            probability <= 0;
            done <= 0;
            cycle_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALC_COMB;
                        cycle_count <= 0;
                        // Calculate k_min = ceil(p/t)
                        k_min = (p + t - 1) / t;
                        // Calculate max_k = min(n, m)
                        max_k = (n < m) ? n : m;
                        accumulator <= 0;
                    end
                end

                CALC_COMB: begin
                    if (cycle_count < (max_k - k_min + 1)) begin
                        current_k = k_min + cycle_count;
                        accumulator <= accumulator + 
                                       comb_table[p][current_k] * 
                                       comb_table[m-p][n-current_k];
                        cycle_count <= cycle_count + 1;
                    end else begin
                        state <= DIVIDE;
                        cycle_count <= 0;
                        denominator <= comb_table[m][n];
                        remainder_div <= {accumulator, 19'b0}; // Pad to 51 bits
                        quotient <= 0;
                        div_cycle_count <= 0;
                    end
                end

                DIVIDE: begin
                    if (div_cycle_count < 12) begin
                        remainder_div <= remainder_div << 3; // Shift 3 bits left
                        if (remainder_div >= 3 * denominator) begin
                            remainder_div <= remainder_div - (3 * denominator);
                            quotient <= (quotient << 3) | 3'b100;
                        end else if (remainder_div >= 2 * denominator) begin
                            remainder_div <= remainder_div - (2 * denominator);
                            quotient <= (quotient << 3) | 3'b110;
                        end else if (remainder_div >= denominator) begin
                            remainder_div <= remainder_div - denominator;
                            quotient <= (quotient << 3) | 3'b101;
                        end else begin
                            quotient <= (quotient << 3) | 3'b000;
                        end
                        div_cycle_count <= div_cycle_count + 1;
                    end else begin
                        state <= DONE;
                        probability <= quotient;
                        done <= 1;
                    end
                end

                DONE: begin
                    state <= IDLE;
                    done <= 0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule