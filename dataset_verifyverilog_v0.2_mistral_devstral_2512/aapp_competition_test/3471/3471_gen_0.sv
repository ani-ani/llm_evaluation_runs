module xorbonacci_query (
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

    // Parameters
    localparam MAX_CYCLES = 2048;
    localparam HISTORY_SIZE = 16;

    // States
    typedef enum logic [3:0] {
        IDLE,
        LOAD,
        FIND_PERIOD,
        CALC_SUM,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [63:0] history [0:HISTORY_SIZE-1];
    reg [63:0] current_value;
    reg [63:0] next_value;
    reg [$clog2(HISTORY_SIZE)-1:0] history_ptr;
    reg [$clog2(MAX_CYCLES):0] cycle_count;
    reg [63:0] period_start;
    reg [63:0] period_length;
    reg [63:0] pre_period_sum;
    reg [63:0] period_sum;
    reg [63:0] temp_sum;
    reg [63:0] index;
    reg [63:0] remaining;
    reg [63:0] full_periods;
    reg [63:0] partial_sum;
    reg [63:0] i;
    reg [63:0] j;
    reg [63:0] k;
    reg found_period;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = FIND_PERIOD;
            end
            FIND_PERIOD: begin
                if (found_period || cycle_count == MAX_CYCLES) next_state = CALC_SUM;
            end
            CALC_SUM: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers
            for (i = 0; i < HISTORY_SIZE; i = i + 1) begin
                history[i] <= 0;
            end
            current_value <= 0;
            next_value <= 0;
            history_ptr <= 0;
            cycle_count <= 0;
            period_start <= 0;
            period_length <= 0;
            pre_period_sum <= 0;
            period_sum <= 0;
            temp_sum <= 0;
            index <= 0;
            remaining <= 0;
            full_periods <= 0;
            partial_sum <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            found_period <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    // No operation
                end
                LOAD: begin
                    // Load initial values into history buffer
                    for (i = 0; i < K; i = i + 1) begin
                        history[i] <= initial_values[i];
                    end
                    history_ptr <= K;
                    current_value <= initial_values[K-1];
                    cycle_count <= K;
                end
                FIND_PERIOD: begin
                    // Compute next value
                    next_value = 0;
                    for (i = 0; i < K; i = i + 1) begin
                        j = (history_ptr - 1 - i + HISTORY_SIZE) % HISTORY_SIZE;
                        next_value = next_value ^ history[j];
                    end

                    // Check for period
                    if (history_ptr >= K && next_value == history[(history_ptr - K) % HISTORY_SIZE]) begin
                        period_start <= history_ptr - K;
                        period_length <= K;
                        found_period <= 1;
                    end

                    // Update history buffer
                    history[history_ptr % HISTORY_SIZE] <= next_value;
                    history_ptr <= history_ptr + 1;
                    current_value <= next_value;
                    cycle_count <= cycle_count + 1;

                    // If MAX_CYCLES reached, proceed to CALC_SUM
                    if (cycle_count == MAX_CYCLES) begin
                        found_period <= 0;
                    end
                end
                CALC_SUM: begin
                    // Compute pre-period sum
                    pre_period_sum = 0;
                    for (i = 0; i < period_start; i = i + 1) begin
                        pre_period_sum = pre_period_sum ^ history[i % HISTORY_SIZE];
                    end

                    // Compute period sum
                    period_sum = 0;
                    for (i = period_start; i < period_start + period_length; i = i + 1) begin
                        period_sum = period_sum ^ history[i % HISTORY_SIZE];
                    end

                    // Compute result for range [l, r]
                    if (found_period) begin
                        if (r < period_start) begin
                            // Entire range is in pre-period
                            result = 0;
                            for (i = l; i <= r; i = i + 1) begin
                                result = result ^ history[i % HISTORY_SIZE];
                            end
                        end else if (l >= period_start) begin
                            // Entire range is in period
                            full_periods = (r - l + 1) / period_length;
                            remaining = (r - l + 1) % period_length;
                            result = 0;
                            for (i = 0; i < full_periods; i = i + 1) begin
                                result = result ^ period_sum;
                            end
                            for (i = 0; i < remaining; i = i + 1) begin
                                j = (period_start + i) % HISTORY_SIZE;
                                result = result ^ history[j];
                            end
                        end else begin
                            // Range spans pre-period and period
                            partial_sum = 0;
                            for (i = l; i < period_start; i = i + 1) begin
                                partial_sum = partial_sum ^ history[i % HISTORY_SIZE];
                            end
                            full_periods = (r - period_start + 1) / period_length;
                            remaining = (r - period_start + 1) % period_length;
                            result = partial_sum;
                            for (i = 0; i < full_periods; i = i + 1) begin
                                result = result ^ period_sum;
                            end
                            for (i = 0; i < remaining; i = i + 1) begin
                                j = (period_start + i) % HISTORY_SIZE;
                                result = result ^ history[j];
                            end
                        end
                    end else begin
                        // No period found, compute directly
                        result = 0;
                        for (i = l; i <= r; i = i + 1) begin
                            if (i < cycle_count) begin
                                result = result ^ history[i % HISTORY_SIZE];
                            end else begin
                                // If index exceeds computed terms, use last computed value
                                result = result ^ current_value;
                            end
                        end
                    end
                end
                DONE: begin
                    // No operation
                end
            endcase
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else begin
            done <= (current_state == DONE);
        end
    end

endmodule