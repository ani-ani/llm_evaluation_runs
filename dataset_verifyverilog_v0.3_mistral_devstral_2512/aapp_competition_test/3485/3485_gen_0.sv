module stop_counting (
    input clk,
    input rst_n,
    input start,
    input [31:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg done,
    output reg [63:0] result_sum,
    output reg [31:0] result_count
);

    // Parameters
    parameter N = 8;
    parameter SUM_WIDTH = 35; // 32-bit inputs + log2(8) = 35 bits
    localparam COUNT_WIDTH = 5; // count up to 8

    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_PREFIX = 2'd1;
    localparam [1:0] COMPUTE_SUFFIX = 2'd2;
    localparam [1:0] SEARCH = 2'd3;
    localparam [1:0] DONE = 2'd4;

    // Registers
    reg [1:0] state;
    reg [3:0] i_ptr; // 0..N
    reg [3:0] j_ptr; // 1..N+1
    reg [3:0] i;     // current prefix length in search
    reg [3:0] j;     // current suffix start index in search
    reg signed [SUM_WIDTH-1:0] arr_reg [0:N-1];
    reg signed [SUM_WIDTH-1:0] pref [0:N]; // pref[0] = 0, pref[i] = sum of first i cards
    reg signed [SUM_WIDTH-1:0] suff [1:N+1]; // suff[N+1] = 0, suff[j] = sum from j to N
    reg signed [SUM_WIDTH-1:0] best_sum;
    reg [COUNT_WIDTH-1:0] best_count;
    wire signed [SUM_WIDTH-1:0] sum_wire;
    wire [COUNT_WIDTH-1:0] count_wire;
    wire signed [63:0] left;
    wire signed [63:0] right;

    // Combination logic for sum and count
    assign sum_wire = pref[i] + suff[j];
    assign count_wire = i + (N - j + 1); // N=8 => i + (9-j)

    // Multiplication for comparison (signed)
    wire signed [SUM_WIDTH:0] best_count_signed = $signed({1'b0, best_count});
    wire signed [SUM_WIDTH:0] count_wire_signed = $signed({1'b0, count_wire});
    assign left = $signed(sum_wire) * best_count_signed;
    assign right = $signed(best_sum) * count_wire_signed;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_sum <= 64'd0;
            result_count <= 32'd0;
            i_ptr <= 4'd0;
            j_ptr <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            best_sum <= {SUM_WIDTH{1'b0}};
            best_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture input array
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        i_ptr <= 4'd0;
                        state <= COMPUTE_PREFIX;
                    end
                end

                COMPUTE_PREFIX: begin
                    if (i_ptr == 4'd0) begin
                        pref[0] <= {SUM_WIDTH{1'b0}};
                        i_ptr <= 4'd1;
                    end else if (i_ptr <= 4'd8) begin
                        pref[i_ptr] <= pref[i_ptr-1] + arr_reg[i_ptr-1];
                        i_ptr <= i_ptr + 4'd1;
                    end else begin
                        i_ptr <= 4'd0;
                        j_ptr <= 4'd9;
                        state <= COMPUTE_SUFFIX;
                    end
                end

                COMPUTE_SUFFIX: begin
                    if (j_ptr == 4'd9) begin
                        suff[9] <= {SUM_WIDTH{1'b0}};
                        j_ptr <= 4'd8;
                    end else if (j_ptr >= 4'd1) begin
                        suff[j_ptr] <= suff[j_ptr+1] + arr_reg[j_ptr-1];
                        j_ptr <= j_ptr - 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd1; // first pair: i=0, j=1
                        best_sum <= {SUM_WIDTH{1'b0}};
                        best_count <= 5'd1; // represents average 0
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    // Compare current pair with best if count > 0
                    if (count_wire > 5'd0 && left > right) begin
                        best_sum <= sum_wire;
                        best_count <= count_wire;
                    end
                    // Move to next pair
                    if (j == 4'd9) begin
                        // Finished current i
                        if (i == 4'd8) begin
                            state <= DONE;
                        end else begin
                            i <= i + 4'd1;
                            j <= i + 4'd2; // next j = (i+1)+1, using old i
                        end
                    end else begin
                        j <= j + 4'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result_sum <= {{(64-SUM_WIDTH){1'b0}}, best_sum}; // zero-extend to 64 bits
                    result_count <= {{(32-COUNT_WIDTH){1'b0}}, best_count}; // zero-extend to 32 bits
                    // Stay in DONE until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule