module stop_counting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire signed [31:0] cards [0:15],
    output reg signed [31:0] result_int,
    output reg [63:0] result_frac,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Calculation variables
    reg signed [31:0] max_avg_int;
    reg [63:0] max_avg_frac;
    reg [7:0] i_reg, j_reg;
    reg [7:0] i, j;
    reg signed [31:0] prefix_sum, suffix_sum;
    reg signed [31:0] total_sum;
    reg [7:0] count;
    reg [63:0] scaled_avg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_int <= 32'd0;
            result_frac <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            max_avg_int <= 32'd0;
            max_avg_frac <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALCULATING;
                        i_reg <= 8'd0;
                        j_reg <= 8'd0;
                        max_avg_int <= 32'd0;
                        max_avg_frac <= 64'd0;
                    end
                end

                CALCULATING: begin
                    cycle_count <= cycle_count + 8'd1;
                    i = i_reg;
                    j = j_reg;

                    // Calculate prefix sum (0 to i-1)
                    prefix_sum = 32'd0;
                    for (integer k = 0; k < i; k = k + 1) begin
                        prefix_sum = prefix_sum + cards[k];
                    end

                    // Calculate suffix sum (j to N-1)
                    suffix_sum = 32'd0;
                    for (integer k = j; k < N; k = k + 1) begin
                        suffix_sum = suffix_sum + cards[k];
                    end

                    total_sum = prefix_sum + suffix_sum;
                    count = i + (N - j);

                    // Calculate scaled average if count > 0
                    if (count > 0) begin
                        scaled_avg = (total_sum * 64'd4294967296) / count;
                        if (scaled_avg > max_avg_frac || (scaled_avg == max_avg_frac && total_sum / count > max_avg_int)) begin
                            max_avg_frac = scaled_avg;
                            max_avg_int = total_sum / count;
                        end
                    end

                    // Update indices
                    j_reg = j_reg + 8'd1;
                    if (j_reg > N) begin
                        j_reg = i_reg + 8'd1;
                        i_reg = i_reg + 8'd1;
                        if (i_reg > N) begin
                            state <= OUTPUT;
                        end
                    end

                    // Prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_int <= max_avg_int;
                    result_frac <= max_avg_frac;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule