module bug_free_plans (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] b,
    input wire [31:0] mod,
    input wire [8:0] a_0,
    input wire [8:0] a_1,
    input wire [8:0] a_2,
    input wire [8:0] a_3,
    input wire [8:0] a_4,
    input wire [8:0] a_5,
    input wire [8:0] a_6,
    input wire [8:0] a_7,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_DP = 4'd1;
    localparam [3:0] WAIT_START = 4'd2;
    localparam [3:0] FETCH_PROG = 4'd3;
    localparam [3:0] CHECK_A = 4'd4;
    localparam [3:0] UPDATE_DP = 4'd5;
    localparam [3:0] UPDATE_NEXT = 4'd6;
    localparam [3:0] NEXT_PROG = 4'd7;
    localparam [3:0] SUM_RESULT = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    reg [3:0] state;
    reg [3:0] prog_idx;
    reg [3:0] lines;
    reg [3:0] bugs;
    reg [31:0] dp [0:8][0:8];
    reg [8:0] current_a;
    reg [31:0] sum_temp;
    reg [31:0] temp_val;
    reg [31:0] mult_temp;
    reg [3:0] init_lines;
    reg [3:0] init_bugs;
    reg [31:0] accumulator;
    reg [3:0] sum_idx;
    reg cycle_counter;

    // Multiplexer for a_i
    always @(*) begin
        case(prog_idx)
            4'd0: current_a = a_0;
            4'd1: current_a = a_1;
            4'd2: current_a = a_2;
            4'd3: current_a = a_3;
            4'd4: current_a = a_4;
            4'd5: current_a = a_5;
            4'd6: current_a = a_6;
            4'd7: current_a = a_7;
            default: current_a = 9'd0;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            prog_idx <= 4'd0;
            lines <= 4'd0;
            bugs <= 4'd0;
            sum_temp <= 32'd0;
            temp_val <= 32'd0;
            init_lines <= 4'd0;
            init_bugs <= 4'd0;
            accumulator <= 32'd0;
            sum_idx <= 4'd0;
            cycle_counter <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 1'b0;
                    prog_idx <= 4'd0;
                    lines <= 4'd0;
                    bugs <= 4'd0;
                    sum_idx <= 4'd0;
                    accumulator <= 32'd0;
                    sum_temp <= 32'd0;
                    temp_val <= 32'd0;
                    if (start) begin
                        state <= INIT_DP;
                        init_lines <= 4'd0;
                        init_bugs <= 4'd0;
                    end
                end

                INIT_DP: begin
                    // Initialize dp array to 0
                    if (init_lines <= 8 && init_bugs <= 8) begin
                        dp[init_lines][init_bugs] <= 32'd0;
                        if (init_bugs == 8) begin
                            init_bugs <= 4'd0;
                            if (init_lines == 8) begin
                                dp[0][0] <= 32'd1; // Base case
                                state <= WAIT_START;
                            end else begin
                                init_lines <= init_lines + 4'd1;
                            end
                        end else begin
                            init_bugs <= init_bugs + 4'd1;
                        end
                    end else begin
                        state <= WAIT_START;
                    end
                end

                WAIT_START: begin
                    // Check if m is 0 (no lines to write)
                    if (m == 4'd0) begin
                        state <= SUM_RESULT;
                    end else begin
                        state <= FETCH_PROG;
                    end
                end

                FETCH_PROG: begin
                    if (prog_idx >= n) begin
                        state <= SUM_RESULT;
                    end else begin
                        state <= CHECK_A;
                    end
                end

                CHECK_A: begin
                    // Skip if a_i > b (can't write even one line without exceeding bugs)
                    if (current_a > b) begin
                        state <= NEXT_PROG;
                    end else begin
                        lines <= 4'd1;
                        bugs <= current_a;
                        cycle_counter <= 1'b0;
                        state <= UPDATE_DP;
                    end
                end

                UPDATE_DP: begin
                    // Calculate sum: dp[lines][bugs] + dp[lines-1][bugs-current_a]
                    if (lines == 4'd1) begin
                        // dp[1][bugs] gets contribution from dp[0][0] (which is 1)
                        if (bugs == current_a) begin
                            dp[lines][bugs] <= 32'd1;
                        end else begin
                            dp[lines][bugs] <= 32'd0;
                        end
                    end else begin
                        temp_val <= dp[lines-1][bugs - current_a];
                        cycle_counter <= 1'b1;
                        state <= UPDATE_NEXT;
                    end
                    
                    // Next iteration logic
                    if (bugs == b) begin
                        bugs <= current_a;
                        if (lines == m) begin
                            prog_idx <= prog_idx + 4'd1;
                            state <= NEXT_PROG;
                        end else begin
                            lines <= lines + 4'd1;
                            state <= UPDATE_DP;
                        end
                    end else begin
                        bugs <= bugs + 4'd1;
                        state <= UPDATE_DP;
                    end
                end

                UPDATE_NEXT: begin
                    // Second cycle for addition
                    if (cycle_counter == 1'b1) begin
                        sum_temp <= dp[lines][bugs] + temp_val;
                        cycle_counter <= 1'b0;
                        // Continue with loop logic from UPDATE_DP
                        if (bugs == b) begin
                            bugs <= current_a;
                            if (lines == m) begin
                                prog_idx <= prog_idx + 4'd1;
                                state <= NEXT_PROG;
                            end else begin
                                lines <= lines + 4'd1;
                                state <= UPDATE_DP;
                            end
                        end else begin
                            bugs <= bugs + 4'd1;
                            state <= UPDATE_DP;
                        end
                    end else begin
                        // Apply modulo
                        if (sum_temp >= mod) begin
                            dp[lines][bugs] <= sum_temp - mod;
                        end else begin
                            dp[lines][bugs] <= sum_temp;
                        end
                    end
                end

                NEXT_PROG: begin
                    prog_idx <= prog_idx + 4'd1;
                    state <= FETCH_PROG;
                end

                SUM_RESULT: begin
                    if (sum_idx == 4'd0) begin
                        accumulator <= dp[m][sum_idx] % mod;
                        sum_idx <= sum_idx + 4'd1;
                    end else if (sum_idx <= b) begin
                        sum_temp <= accumulator + dp[m][sum_idx];
                        state <= SUM_RESULT;
                        // Will process modulo in next cycle
                    end else begin
                        result <= accumulator;
                        state <= FINISH;
                    end
                end

                SUM_RESULT: begin
                    // Check if we're adding or doing modulo
                    if (sum_idx <= b) begin
                        if (sum_temp >= mod) begin
                            accumulator <= sum_temp - mod;
                        end else begin
                            accumulator <= sum_temp;
                        end
                        sum_idx <= sum_idx + 4'd1;
                        // Continue loop
                        if (sum_idx < b) begin
                            sum_temp <= accumulator + dp[m][sum_idx + 4'd1];
                        end
                    end else begin
                        result <= accumulator;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule