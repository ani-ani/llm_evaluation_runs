module nds_turbo (
    input clk,
    input rst_n,
    input start,
    input [7:0] seq_in,
    input [9:0] T_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        READING,
        CALCULATING,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // Sequence storage
    reg [7:0] sequence [0:7];
    reg [9:0] T_reg;

    // Counters
    reg [2:0] read_counter;
    reg [2:0] calc_counter;

    // LIS computation variables
    reg [3:0] total;
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] gap;
    reg [7:0] max_val;
    reg [7:0] min_val;

    // LIS computation helper
    function automatic [3:0] compute_lis(input [7:0] seq [0:7], input start_idx, input end_idx);
        reg [3:0] dp [0:7];
        integer i, j;
        
        for (i = start_idx; i <= end_idx; i = i + 1) begin
            dp[i] = 1;
            for (j = start_idx; j < i; j = j + 1) begin
                if (seq[j] <= seq[i] && dp[j] + 1 > dp[i]) begin
                    dp[i] = dp[j] + 1;
                end
            end
        end
        
        dp[0] = 1;
        for (i = start_idx + 1; i <= end_idx; i = i + 1) begin
            if (dp[i] > dp[0]) begin
                dp[0] = dp[i];
            end
        end
        
        compute_lis = dp[0];
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            read_counter <= 0;
            calc_counter <= 0;
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
                if (start) begin
                    next_state = READING;
                end
            end
            READING: begin
                if (read_counter == 7) begin
                    next_state = CALCULATING;
                end
            end
            CALCULATING: begin
                if (calc_counter == 7) begin
                    next_state = FINISHED;
                end
            end
            FINISHED: begin
                next_state = IDLE;
            end
        endcase
    end

    // Reading phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_counter <= 0;
        end else if (current_state == READING) begin
            if (read_counter < 8) begin
                sequence[read_counter] <= seq_in;
                if (read_counter == 0) begin
                    T_reg <= T_in;
                end
                read_counter <= read_counter + 1;
            end
        end
    end

    // Calculation phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_counter <= 0;
            total <= 0;
            left <= 0;
            right <= 0;
            gap <= 0;
            max_val <= 0;
            min_val <= 255;
        end else if (current_state == CALCULATING) begin
            case (calc_counter)
                0: begin
                    // Compute total LIS
                    total = compute_lis(sequence, 0, 7);
                    // Compute left LIS (prefix)
                    left = compute_lis(sequence, 0, 3);
                    calc_counter <= calc_counter + 1;
                end
                1: begin
                    // Compute right LIS (suffix)
                    right = compute_lis(sequence, 4, 7);
                    calc_counter <= calc_counter + 1;
                end
                2: begin
                    // Find max and min values
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (sequence[i] > max_val) begin
                            max_val = sequence[i];
                        end
                        if (sequence[i] < min_val) begin
                            min_val = sequence[i];
                        end
                    end
                    calc_counter <= calc_counter + 1;
                end
                3: begin
                    // Compute gap
                    if (max_val <= min_val) begin
                        gap = 1;
                    end else begin
                        gap = 2;
                    end
                    calc_counter <= calc_counter + 1;
                end
                4: begin
                    // Final computation
                    if (T_reg == 1) begin
                        result = total;
                    end else begin
                        result = left + right + (T_reg - 2) * gap + (total - left - right);
                    end
                    calc_counter <= calc_counter + 1;
                end
                default: begin
                    calc_counter <= calc_counter + 1;
                end
            endcase
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == FINISHED) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule