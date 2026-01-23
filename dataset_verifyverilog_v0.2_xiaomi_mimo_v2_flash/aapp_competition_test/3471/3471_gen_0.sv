module xorbonacci_query(
    input clk,
    input rst_n,
    input start,
    input [2:0] K,
    input [63:0] initial_values [0:7],
    input [63:0] l,
    input [63:0] r,
    output reg [63:0] result,
    output reg done
);

    parameter MAX_CYCLES = 2048;
    parameter HIST_SIZE = 16;
    parameter MAX_K = 8;

    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam FIND_PERIOD = 3'b010;
    localparam CALC_SUM = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [63:0] x [0:MAX_K-1];
    reg [63:0] seq_mem [0:HIST_SIZE-1];
    reg [15:0] cycle_cnt;
    reg [15:0] period_len;
    reg [63:0] term_idx;
    reg [63:0] xor_acc;
    reg [15:0] seq_ptr;
    reg sum_started;
    integer i;

    // Helper for modulo calculation
    wire [15:0] init_seq_ptr;
    assign init_seq_ptr = (period_len == 0 || l <= K) ? 0 : ((l - K - 1) % period_len);

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            LOAD: next_state = FIND_PERIOD;
            FIND_PERIOD: begin
                if (period_len != 0) next_state = CALC_SUM;
                else if (cycle_cnt >= HIST_SIZE) next_state = CALC_SUM;
                else next_state = FIND_PERIOD;
            end
            CALC_SUM: begin
                if (term_idx > r) next_state = DONE;
                else next_state = CALC_SUM;
            end
            DONE: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            result <= 0;
            cycle_cnt <= 0;
            period_len <= 0;
            term_idx <= 1;
            xor_acc <= 0;
            sum_started <= 0;
            for (i = 0; i < MAX_K; i = i + 1) x[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                end

                LOAD: begin
                    // Load initial values into shift register
                    for (i = 0; i < MAX_K; i = i + 1) begin
                        if (i < K) x[i] <= initial_values[K - 1 - i];
                        else x[i] <= 0;
                    end
                    cycle_cnt <= 0;
                    period_len <= 0;
                    sum_started <= 0;
                end

                FIND_PERIOD: begin
                    if (cycle_cnt < HIST_SIZE && period_len == 0) begin
                        // Generate next value
                        reg [63:0] next_val;
                        next_val = 0;
                        for (i = 0; i < MAX_K; i = i + 1) begin
                            if (i < K) next_val = next_val ^ x[i];
                        end

                        // Check for cycle against seq_mem
                        reg match_found;
                        match_found = 0;
                        for (i = 0; i < HIST_SIZE; i = i + 1) begin
                            if (i < cycle_cnt && seq_mem[i] == next_val) match_found = 1;
                        end

                        if (match_found) begin
                            seq_mem[cycle_cnt] <= next_val;
                            period_len <= cycle_cnt + 1;
                        end else begin
                            // Update shift register
                            for (i = MAX_K - 1; i > 0; i = i - 1) begin
                                if (i - 1 < K - 1) x[i] <= x[i-1];
                            end
                            x[0] <= next_val;
                            seq_mem[cycle_cnt] <= next_val;
                            cycle_cnt <= cycle_cnt + 1;
                        end
                    end else if (cycle_cnt >= HIST_SIZE && period_len == 0) begin
                        // Buffer full, no period found, use full buffer as period
                        period_len <= cycle_cnt;
                    end
                end

                CALC_SUM: begin
                    if (!sum_started) begin
                        sum_started <= 1;
                        term_idx <= l;
                        xor_acc <= 0;
                        seq_ptr <= init_seq_ptr;
                    end else begin
                        if (term_idx <= r) begin
                            reg [63:0] val;
                            val = 0;
                            if (term_idx <= K) begin
                                val = initial_values[term_idx - 1];
                            end else begin
                                if (period_len > 0 && seq_ptr < HIST_SIZE)
                                    val = seq_mem[seq_ptr];
                                // Update seq_ptr
                                if (seq_ptr + 1 >= period_len)
                                    seq_ptr <= 0;
                                else
                                    seq_ptr <= seq_ptr + 1;
                            end
                            xor_acc <= xor_acc ^ val;
                            term_idx <= term_idx + 1;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    result <= xor_acc;
                end
            endcase
        end
    end
endmodule