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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FETCH_A = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] lines;
    reg [3:0] bugs;
    reg [3:0] init_lines;
    reg [3:0] init_bugs;
    reg [3:0] sum_bugs;

    reg [31:0] dp [0:8][0:8];
    reg [8:0] current_a;
    reg [31:0] sum_update;

    always @(*) begin
        case(i)
            3'd0: current_a = a_0;
            3'd1: current_a = a_1;
            3'd2: current_a = a_2;
            3'd3: current_a = a_3;
            3'd4: current_a = a_4;
            3'd5: current_a = a_5;
            3'd6: current_a = a_6;
            3'd7: current_a = a_7;
            default: current_a = 9'd0;
        endcase
    end

    always @(*) begin
        if (lines >= 1 && bugs >= current_a && (bugs - current_a) <= 8) begin
            sum_update = dp[lines][bugs] + dp[lines-1][bugs - current_a];
            if (sum_update >= mod) sum_update = sum_update - mod;
        end else begin
            sum_update = dp[lines][bugs];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i <= 3'd0;
            lines <= 3'd0;
            bugs <= 3'd0;
            init_lines <= 3'd0;
            init_bugs <= 3'd0;
            sum_bugs <= 3'd0;
        end else begin
            case(state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 1'b0;
                        result <= 32'd0;
                        i <= 3'd0;
                        lines <= 3'd0;
                        bugs <= 3'd0;
                        init_lines <= 3'd0;
                        init_bugs <= 3'd0;
                        sum_bugs <= 3'd0;
                    end
                end

                INIT: begin
                    if (init_lines <= 8 && init_bugs <= 8) begin
                        dp[init_lines][init_bugs] <= 32'd0;
                        if (init_bugs == 8) begin
                            init_bugs <= 3'd0;
                            if (init_lines == 8) begin
                                dp[0][0] <= 32'd1;
                                state <= FETCH_A;
                            end else begin
                                init_lines <= init_lines + 1;
                            end
                        end else begin
                            init_bugs <= init_bugs + 1;
                        end
                    end else begin
                        state <= FETCH_A;
                    end
                end

                FETCH_A: begin
                    if (i >= n) begin
                        state <= SUM;
                        sum_bugs <= 3'd0;
                    end else begin
                        if (current_a > b) begin
                            i <= i + 1;
                        end else if (m == 0) begin
                            i <= i + 1;
                        end else begin
                            lines <= 3'd1;
                            bugs <= current_a;
                            state <= UPDATE;
                        end
                    end
                end

                UPDATE: begin
                    dp[lines][bugs] <= sum_update;
                    if (bugs == b) begin
                        bugs <= current_a;
                        if (lines == m) begin
                            i <= i + 1;
                            state <= FETCH_A;
                        end else begin
                            lines <= lines + 1;
                        end
                    end else begin
                        bugs <= bugs + 1;
                    end
                end

                SUM: begin
                    if (sum_bugs == 0) begin
                        result <= dp[m][sum_bugs] % mod;
                    end else begin
                        if (result + dp[m][sum_bugs] >= mod)
                            result <= result + dp[m][sum_bugs] - mod;
                        else
                            result <= result + dp[m][sum_bugs];
                    end
                    if (sum_bugs == b) begin
                        state <= DONE;
                    end else begin
                        sum_bugs <= sum_bugs + 1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule