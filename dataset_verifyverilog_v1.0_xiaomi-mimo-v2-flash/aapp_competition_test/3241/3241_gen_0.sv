module ham_distributor(
    input clk,
    input rst_n,
    input start,
    input [31:0] A [0:7],
    input [31:0] B [0:7],
    output reg [31:0] H_out,
    output reg found,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Registers
    reg [1:0] state;
    reg [7:0] i;                 // Candidate H index (0 to 255)
    reg [31:0] H_current;        // Current H candidate (Q16.16)
    reg [31:0] total [0:7];      // Total[k] values
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Intermediate calculations for Total[k] = A[k] + (B[k] * H)
    // Use 64-bit for multiplication result
    reg [63:0] mult_temp [0:7];
    reg [31:0] mult_result [0:7];
    reg [31:0] sum_result [0:7];

    // Comparator signals
    reg ordering_valid;
    reg [2:0] comp_idx;
    reg [3:0] ordering_check_count;

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            H_out <= 32'd0;
            found <= 1'b0;
            done <= 1'b0;
            i <= 8'd0;
            H_current <= 32'd0;
            cycle_count <= 8'd0;
            ordering_check_count <= 4'd0;
            comp_idx <= 3'd0;
            for (j = 0; j < 8; j = j + 1) begin
                total[j] <= 32'd0;
                mult_temp[j] <= 64'd0;
                mult_result[j] <= 32'd0;
                sum_result[j] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    i <= 8'd0;
                    H_current <= 32'd0;
                    cycle_count <= 8'd0;
                    ordering_check_count <= 4'd0;
                    if (start) begin
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    // Calculate Total values for current i
                    // H_current = i << 16 (scale integer i to Q16.16)
                    H_current <= {i, 16'd0};

                    // Compute Multiplications and Sums (sequential for timing)
                    // Using if-else chain instead of for-loop for synthesis compatibility
                    if (ordering_check_count == 4'd0) begin
                        // Calculate Total[0]
                        mult_temp[0] <= A[0] * {i, 16'd0};
                        mult_result[0] <= mult_temp[0][47:16];
                        sum_result[0] <= A[0] + mult_result[0];
                        total[0] <= sum_result[0];
                        ordering_check_count <= 4'd1;
                    end else if (ordering_check_count == 4'd1) begin
                        // Calculate Total[1]
                        mult_temp[1] <= A[1] * {i, 16'd0};
                        mult_result[1] <= mult_temp[1][47:16];
                        sum_result[1] <= A[1] + mult_result[1];
                        total[1] <= sum_result[1];
                        ordering_check_count <= 4'd2;
                    end else if (ordering_check_count == 4'd2) begin
                        // Calculate Total[2]
                        mult_temp[2] <= A[2] * {i, 16'd0};
                        mult_result[2] <= mult_temp[2][47:16];
                        sum_result[2] <= A[2] + mult_result[2];
                        total[2] <= sum_result[2];
                        ordering_check_count <= 4'd3;
                    end else if (ordering_check_count == 4'd3) begin
                        // Calculate Total[3]
                        mult_temp[3] <= A[3] * {i, 16'd0};
                        mult_result[3] <= mult_temp[3][47:16];
                        sum_result[3] <= A[3] + mult_result[3];
                        total[3] <= sum_result[3];
                        ordering_check_count <= 4'd4;
                    end else if (ordering_check_count == 4'd4) begin
                        // Calculate Total[4]
                        mult_temp[4] <= A[4] * {i, 16'd0};
                        mult_result[4] <= mult_temp[4][47:16];
                        sum_result[4] <= A[4] + mult_result[4];
                        total[4] <= sum_result[4];
                        ordering_check_count <= 4'd5;
                    end else if (ordering_check_count == 4'd5) begin
                        // Calculate Total[5]
                        mult_temp[5] <= A[5] * {i, 16'd0};
                        mult_result[5] <= mult_temp[5][47:16];
                        sum_result[5] <= A[5] + mult_result[5];
                        total[5] <= sum_result[5];
                        ordering_check_count <= 4'd6;
                    end else if (ordering_check_count == 4'd6) begin
                        // Calculate Total[6]
                        mult_temp[6] <= A[6] * {i, 16'd0};
                        mult_result[6] <= mult_temp[6][47:16];
                        sum_result[6] <= A[6] + mult_result[6];
                        total[6] <= sum_result[6];
                        ordering_check_count <= 4'd7;
                    end else if (ordering_check_count == 4'd7) begin
                        // Calculate Total[7]
                        mult_temp[7] <= A[7] * {i, 16'd0};
                        mult_result[7] <= mult_temp[7][47:16];
                        sum_result[7] <= A[7] + mult_result[7];
                        total[7] <= sum_result[7];
                        ordering_check_count <= 4'd8;
                    end else if (ordering_check_count == 4'd8) begin
                        // Check Ordering: Total[comp_idx] > Total[comp_idx + 1]
                        if (total[comp_idx] > total[comp_idx + 1]) begin
                            if (comp_idx == 3'd6) begin
                                // All comparisons passed
                                H_out <= {i, 16'd0};
                                found <= 1'b1;
                                state <= FINISH;
                                ordering_check_count <= 4'd0;
                                comp_idx <= 3'd0;
                            end else begin
                                comp_idx <= comp_idx + 3'd1;
                            end
                        end else begin
                            // Ordering failed, move to next i
                            comp_idx <= 3'd0;
                            ordering_check_count <= 4'd0;
                            if (i == 8'd255) begin
                                state <= FINISH;
                                found <= 1'b0;
                            end else begin
                                i <= i + 8'd1;
                                cycle_count <= cycle_count + 8'd1;
                                if (cycle_count >= MAX_CYCLES) begin
                                    state <= FINISH;
                                    found <= 1'b0;
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule