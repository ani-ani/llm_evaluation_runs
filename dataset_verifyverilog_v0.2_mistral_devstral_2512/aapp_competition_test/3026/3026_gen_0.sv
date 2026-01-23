module critical_elements (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] seq [0:7],
    output reg [7:0] critical_mask,
    output reg done,
    output reg error
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CHECK_L0,
        CHECK_L1,
        CHECK_L2,
        CHECK_L3,
        CHECK_L4,
        CHECK_L5,
        CHECK_L6,
        CHECK_L7,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [7:0] lis_lengths [0:7];
    reg [7:0] original_lis;
    reg [2:0] current_index;
    reg [7:0] temp_lis;
    reg [7:0] temp_mask;

    // LIS computation function (unrolled for small n)
    function automatic [7:0] compute_lis(input [7:0] seq_local [0:7], input [2:0] n_local);
        reg [7:0] dp [0:7];
        integer i, j;
        
        for (i = 0; i < n_local; i = i + 1) begin
            dp[i] = 1;
            for (j = 0; j < i; j = j + 1) begin
                if (seq_local[j] < seq_local[i] && dp[j] + 1 > dp[i]) begin
                    dp[i] = dp[j] + 1;
                end
            end
        end
        
        compute_lis = dp[0];
        for (i = 1; i < n_local; i = i + 1) begin
            if (dp[i] > compute_lis) begin
                compute_lis = dp[i];
            end
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            critical_mask <= 0;
            current_index <= 0;
            original_lis <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        done = 0;
        error = 0;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n < 2 || n > 8) begin
                        error = 1;
                        done = 1;
                        next_state = DONE;
                    end else begin
                        original_lis = compute_lis(seq, n);
                        current_index = 0;
                        next_state = CHECK_L0;
                    end
                end
            end
            CHECK_L0: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 1;
                next_state = CHECK_L1;
            end
            CHECK_L1: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 2;
                next_state = CHECK_L2;
            end
            CHECK_L2: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 3;
                next_state = CHECK_L3;
            end
            CHECK_L3: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 4;
                next_state = CHECK_L4;
            end
            CHECK_L4: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 5;
                next_state = CHECK_L5;
            end
            CHECK_L5: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 6;
                next_state = CHECK_L6;
            end
            CHECK_L6: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                current_index = 7;
                next_state = CHECK_L7;
            end
            CHECK_L7: begin
                temp_lis = compute_lis(seq, n, current_index);
                if (temp_lis < original_lis) begin
                    temp_mask[current_index] = 1;
                end else begin
                    temp_mask[current_index] = 0;
                end
                critical_mask = temp_mask;
                next_state = DONE;
            end
            DONE: begin
                done = 1;
            end
        endcase
    end

    // Modified LIS computation function (excluding one element)
    function automatic [7:0] compute_lis(input [7:0] seq_local [0:7], input [2:0] n_local, input [2:0] exclude_index);
        reg [7:0] dp [0:7];
        integer i, j;
        
        for (i = 0; i < n_local; i = i + 1) begin
            if (i == exclude_index) begin
                dp[i] = 0;
            end else begin
                dp[i] = 1;
                for (j = 0; j < i; j = j + 1) begin
                    if (j != exclude_index && seq_local[j] < seq_local[i] && dp[j] + 1 > dp[i]) begin
                        dp[i] = dp[j] + 1;
                    end
                end
            end
        end
        
        compute_lis = dp[0];
        for (i = 1; i < n_local; i = i + 1) begin
            if (dp[i] > compute_lis) begin
                compute_lis = dp[i];
            end
        end
    endfunction

endmodule