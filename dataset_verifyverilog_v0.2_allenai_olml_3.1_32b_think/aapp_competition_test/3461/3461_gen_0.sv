module hearing_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] s [0:7],
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [31:0] result,
    output reg done
);

// Internal registers
reg [7:0] s_reg [0:7];
reg [7:0] a_reg [0:7];
reg [7:0] b_reg [0:7];
reg [2:0] n_reg;
reg [31:0] dp [0:7];
reg [31:0] numerator;
reg [7:0] denominator;
reg [8:0] t_start, t_end;
reg [8:0] t_counter;
reg [3:0] i, current_j;
reg [3:0] j_found;
reg [31:0] temp;
reg [31:0] e_skip;
reg [31:0] e_attend;
reg [31:0] max_val;
reg [31:0] one; // 65536
reg [13:0] delay_counter;
reg state;
localparam IDLE = 3'b000,
        LOAD = 3'b001,
        INIT = 3'b010,
        PROCESS_I = 3'b011,
        PROCESS_T = 3'b100,
        PROCESS_J = 3'b101,
        COMPUTE_ATTEND = 3'b110,
        COMPUTE_MAX = 3'b111,
        WAIT_DELAY = 3'b000,
        DONE_STATE = 3'b000;

// Initialize 'one' to 65536
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        s_reg <= 0;
        a_reg <= 0;
        b_reg <= 0;
        n_reg <= 0;
        dp <= 0;
        numerator <= 0;
        denominator <= 0;
        t_start <= 0;
        t_end <= 0;
        t_counter <= 0;
        i <= 0;
        current_j <= 0;
        j_found <= 0;
        temp <= 0;
        e_skip <= 0;
        e_attend <= 0;
        max_val <= 0;
        one <= 32'd65536;
        delay_counter <= 0;
        state <= IDLE;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
                else state <= IDLE;
            end
            LOAD: begin
                n_reg <= n;
                s_reg <= s;
                a_reg <= a;
                b_reg <= b;
                state <= INIT;
            end
            INIT: begin
                if (n_reg == 0) begin
                    i <= 0;
                end else begin
                    i <= n_reg - 1;
                end
                state <= PROCESS_I;
            end
            PROCESS_I: begin
                t_start <= s_reg[i] + a_reg[i];
                t_end <= s_reg[i] + b_reg[i];
                denominator <= t_end - t_start + 1;
                numerator <= 0;
                t_counter <= t_start;
                if (t_counter <= t_end) begin
                    state <= PROCESS_T;
                end else begin
                    state <= COMPUTE_ATTEND;
                end
            end
            PROCESS_T: begin
                if (t_counter > t_end) begin
                    state <= COMPUTE_ATTEND;
                end else begin
                    current_j <= i + 1;
                    state <= PROCESS_J;
                end
            end
            PROCESS_J: begin
                if (current_j >= n_reg) begin
                    j_found <= n_reg;
                    numerator <= numerator + (one + dp[j_found]); // Potential bug
                    t_counter <= t_counter + 1;
                    if (t_counter > t_end) begin
                        state <= COMPUTE_ATTEND;
                    end else begin
                        state <= PROCESS_T;
                    end
                end else begin
                    if (s_reg[current_j] >= t_counter) begin
                        j_found <= current_j;
                        numerator <= numerator + (one + dp[j_found]);
                        t_counter <= t_counter + 1;
                        if (t_counter > t_end) begin
                            state <= COMPUTE_ATTEND;
                        end else begin
                            state <= PROCESS_T;
                        end
                    end else begin
                        current_j <= current_j + 1;
                        state <= PROCESS_J;
                    end
                end
            end
            COMPUTE_ATTEND: begin
                e_attend = numerator / denominator;
                if (i + 1 < n_reg) begin
                    e_skip = dp[i + 1];
                end else begin
                    e_skip = 0;
                end
                max_val = (e_attend > e_skip) ? e_attend : e_skip;
                dp[i] = max_val;
                if (i > 0) begin
                    i <= i - 1;
                    state <= PROCESS_I;
                end else begin
                    result <= dp[0];
                    state <= WAIT_DELAY;
                end
            end
            COMPUTE_MAX: // Not used? Maybe remove this state
                state <= IDLE;
            end
            WAIT_DELAY: begin
                if (delay_counter == 9999) begin
                    done <= 1;
                    state <= DONE_STATE;
                end else begin
                    delay_counter <= delay_counter + 1;
                    state <= WAIT_DELAY;
                end
            end
            DONE_STATE: begin
                done <= 1;
                state <= DONE_STATE;
            end
        endcase
    end
endmodule