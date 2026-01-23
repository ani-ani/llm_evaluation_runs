module fence_posts (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] K,
    input wire [3:0] N,
    input wire [7:0] p [0:7],
    output reg [7:0] cuts,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] FIND_L      = 4'd1;
    localparam [3:0] CHECK_L     = 4'd2;
    localparam [3:0] COMPUTE_D   = 4'd3;
    localparam [3:0] SORT_D      = 4'd4;
    localparam [3:0] FIND_T      = 4'd5;
    localparam [3:0] CALC_RESULT = 4'd6;
    localparam [3:0] DONE_STATE  = 4'd7;
    localparam [3:0] DIV_LOOP    = 4'd8;
    localparam [3:0] MOD_LOOP    = 4'd9;
    localparam [3:0] SORT_LOOP   = 4'd10;
    localparam [3:0] FIND_T_LOOP = 4'd11;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] L;
    reg [7:0] max_L;
    reg [7:0] temp_sum;
    reg [7:0] D [0:7];
    reg [2:0] D_size;
    reg [7:0] prefix_sum;
    reg [2:0] t;
    reg [7:0] cuts_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper registers for division/modulo
    reg [7:0] div_a;
    reg [7:0] div_b;
    reg [7:0] div_count;
    reg [7:0] mod_val;
    reg [7:0] quotient;
    reg [7:0] remainder;
    reg [2:0] i_idx;
    reg [2:0] j_idx;
    reg [2:0] k_idx;
    reg [7:0] temp_val;
    reg [7:0] temp_val2;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cuts <= 8'd0;
            done <= 1'b0;
            L <= 8'd0;
            max_L <= 8'd0;
            temp_sum <= 8'd0;
            D_size <= 3'd0;
            prefix_sum <= 8'd0;
            t <= 3'd0;
            cuts_reg <= 8'd0;
            cycle_count <= 8'd0;
            div_a <= 8'd0;
            div_b <= 8'd0;
            div_count <= 8'd0;
            mod_val <= 8'd0;
            quotient <= 8'd0;
            remainder <= 8'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            k_idx <= 3'd0;
            temp_val <= 8'd0;
            temp_val2 <= 8'd0;
            // Initialize D array
            D[0] <= 8'd0; D[1] <= 8'd0; D[2] <= 8'd0; D[3] <= 8'd0;
            D[4] <= 8'd0; D[5] <= 8'd0; D[6] <= 8'd0; D[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FIND_L;
                        // Initialize max_L to first pole
                        max_L <= p[0];
                        i_idx <= 3'd1;
                    end
                end

                FIND_L: begin
                    if (i_idx < K) begin
                        if (p[i_idx] > max_L) begin
                            max_L <= p[i_idx];
                        end
                        i_idx <= i_idx + 3'd1;
                    end else begin
                        L <= max_L;
                        state <= CHECK_L;
                        temp_sum <= 8'd0;
                        i_idx <= 3'd0;
                        div_b <= max_L;
                    end
                end

                CHECK_L: begin
                    if (L > 8'd0) begin
                        if (i_idx < K) begin
                            div_a <= p[i_idx];
                            div_count <= 8'd0;
                            state <= DIV_LOOP;
                        end else begin
                            if (temp_sum >= N) begin
                                state <= COMPUTE_D;
                                D_size <= 3'd0;
                                i_idx <= 3'd0;
                            end else begin
                                L <= L - 8'd1;
                                state <= CHECK_L;
                                temp_sum <= 8'd0;
                                i_idx <= 3'd0;
                            end
                        end
                    end else begin
                        // L reached 0, should not happen per constraints
                        state <= DONE_STATE;
                        cuts_reg <= N[7:0];
                    end
                end

                DIV_LOOP: begin
                    if (div_a >= div_b) begin
                        div_a <= div_a - div_b;
                        div_count <= div_count + 8'd1;
                    end else begin
                        temp_sum <= temp_sum + div_count;
                        i_idx <= i_idx + 3'd1;
                        state <= CHECK_L;
                    end
                end

                COMPUTE_D: begin
                    if (i_idx < K) begin
                        div_a <= p[i_idx];
                        div_b <= L;
                        div_count <= 8'd0;
                        state <= MOD_LOOP;
                    end else begin
                        state <= SORT_D;
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        temp_val <= 8'd0;
                        temp_val2 <= 8'd0;
                    end
                end

                MOD_LOOP: begin
                    if (div_a >= div_b) begin
                        div_a <= div_a - div_b;
                    end else begin
                        // remainder = div_a
                        if (div_a == 8'd0) begin
                            // Divisible
                            div_a <= p[i_idx];
                            div_b <= L;
                            div_count <= 8'd0;
                            state <= DIV_LOOP; // Get quotient
                        end else begin
                            // Not divisible
                            i_idx <= i_idx + 3'd1;
                            state <= COMPUTE_D;
                        end
                    end
                end

                SORT_D: begin
                    if (D_size > 3'd1) begin
                        if (j_idx < D_size - 3'd1) begin
                            if (D[j_idx] > D[j_idx + 3'd1]) begin
                                temp_val <= D[j_idx];
                                temp_val2 <= D[j_idx + 3'd1];
                                D[j_idx] <= D[j_idx + 3'd1];
                                D[j_idx + 3'd1] <= temp_val;
                                state <= SORT_LOOP;
                            end else begin
                                j_idx <= j_idx + 3'd1;
                            end
                        end else begin
                            j_idx <= 3'd0;
                            i_idx <= i_idx + 3'd1;
                            if (i_idx < D_size - 3'd1) begin
                                state <= SORT_D;
                            end else begin
                                state <= FIND_T;
                                prefix_sum <= 8'd0;
                                t <= 3'd0;
                                k_idx <= 3'd0;
                            end
                        end
                    end else begin
                        state <= FIND_T;
                        prefix_sum <= 8'd0;
                        t <= 3'd0;
                        k_idx <= 3'd0;
                    end
                end

                SORT_LOOP: begin
                    // Delay for swap
                    state <= SORT_D;
                end

                FIND_T: begin
                    if (k_idx < D_size) begin
                        if (prefix_sum + D[k_idx] <= N) begin
                            prefix_sum <= prefix_sum + D[k_idx];
                            t <= t + 3'd1;
                            k_idx <= k_idx + 3'd1;
                        end else begin
                            state <= CALC_RESULT;
                        end
                    end else begin
                        state <= CALC_RESULT;
                    end
                end

                CALC_RESULT: begin
                    cuts_reg <= N[7:0] - {5'd0, t};
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    cuts <= cuts_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
                cuts_reg <= 8'd0;
            end
        end
    end

    // Continuous assignment for division result (when in appropriate state)
    always @(*) begin
        if (state == DIV_LOOP && div_a < div_b) begin
            quotient = div_count;
        end else if (state == MOD_LOOP && div_a < div_b) begin
            remainder = div_a;
        end
    end

endmodule