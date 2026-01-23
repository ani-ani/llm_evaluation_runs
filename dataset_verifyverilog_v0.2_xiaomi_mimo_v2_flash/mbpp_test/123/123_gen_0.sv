module amicable_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] limit,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // Parameters for states
    localparam IDLE = 5'b00001;
    localparam CHECK_INPUT = 5'b00010;
    localparam PROCESS = 5'b00100;
    localparam VALIDATE = 5'b01000;
    localparam SUM_UP = 5'b10000;
    // Note: DONE is handled by done signal and staying in IDLE logic or separate state
    // We will use a dedicated DONE state to hold output
    localparam DONE = 5'b11111;

    localparam NUM_MAX = 100;

    reg [4:0] state;
    
    // Processing counters
    reg [7:0] curr_num;     // Current number being processed (2 to 100)
    reg [7:0] div;          // Divisor
    reg [15:0] div_sum_acc; // Accumulator for sum of divisors for curr_num
    
    // Storage for divisor sums (indices 2 to 100). 
    // We need indices 0..100, so size 101. 16 bits per entry.
    reg [15:0] div_sums [0:100];
    
    // Amicable markers (indices 2 to 100)
    reg [0:0] amicable_mark [0:100]; // 1 if part of an amicable pair
    
    // Temporary variables for validation loop
    reg [7:0] val_i;
    reg [7:0] val_j;
    reg check_passed;
    
    // Loop limits
    reg [7:0] limit_reg;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            error <= 1'b0;
            curr_num <= 8'd0;
            div <= 8'd0;
            div_sum_acc <= 16'b0;
            val_i <= 8'd0;
            val_j <= 8'd0;
            limit_reg <= 8'd0;
            check_passed <= 1'b0;
            // Reset storage arrays
            for (i = 0; i <= 100; i = i + 1) begin
                div_sums[i] <= 16'b0;
                amicable_mark[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    result <= 16'b0;
                    if (start) begin
                        state <= CHECK_INPUT;
                        limit_reg <= (limit > NUM_MAX) ? NUM_MAX : limit;
                    end
                end

                CHECK_INPUT: begin
                    if (limit_reg < 2) begin
                        error <= 1'b1;
                        state <= DONE;
                    end else begin
                        error <= 1'b0;
                        state <= PROCESS;
                        curr_num <= 8'd2;
                        div <= 8'd1; // Start divisor at 1
                        div_sum_acc <= 16'b0;
                    end
                end

                PROCESS: begin
                    // Logic to compute sum of proper divisors for curr_num
                    // We iterate div from 1 up to curr_num - 1 (effectively curr_num/2 is enough, but full check is safe)
                    // Optimization: proper divisors are < num. We check 1 to num/2.
                    // If div < curr_num, continue.
                    
                    if (curr_num <= limit_reg) begin
                        // Calculate sum logic
                        if (div < curr_num) begin
                            // Check if divisor (using modulo)
                            if (curr_num % div == 0) begin
                                div_sum_acc <= div_sum_acc + div;
                            end
                            div <= div + 1;
                            state <= PROCESS;
                        end else begin
                            // Finished this number
                            div_sums[curr_num] <= div_sum_acc;
                            curr_num <= curr_num + 1;
                            div <= 8'd1;
                            div_sum_acc <= 16'b0;
                            
                            if (curr_num + 1 > limit_reg) begin
                                // Transition to validation after incrementing past limit
                                // We need to handle the case where curr_num was just updated
                                // If curr_num became > limit_reg, move to VALIDATE
                                state <= VALIDATE;
                                val_i <= 8'd2;
                                val_j <= 8'd2; // Initialize
                            end else begin
                                state <= PROCESS;
                            end
                        end
                    end else begin
                        // Should catch edge cases, but PROCESS handles range check at top
                        state <= VALIDATE;
                        val_i <= 8'd2;
                        val_j <= 8'd2;
                    end
                end

                VALIDATE: begin
                    // Check amicable pairs: div_sums[val_i] = val_j (where j > i), and div_sums[val_j] = i
                    // Iterate val_i from 2 to limit_reg
                    // Iterate val_j from val_i + 1 to limit_reg
                    
                    if (val_i < limit_reg) begin
                        val_j <= val_j + 1;
                        
                        // Boundary check for j
                        if (val_j > limit_reg) begin
                            val_i <= val_i + 1;
                            val_j <= val_i + 2; // Start j at i+1 next iteration (i incremented, so j=i+1, but we add 1 in step, so start at i+2)
                            if (val_i + 1 >= limit_reg) state <= SUM_UP; // Finished all i
                        end else begin
                            // Valid range check
                            // Check if div_sums[val_i] equals val_j and div_sums[val_j] equals val_i
                            // Also check that div_sums are valid (non-zero for amicable pairs usually, but math definition works)
                            // Note: div_sums stores the sum. We check strict equality.
                            // Condition: ds[i] == j AND ds[j] == i
                            
                            if ((div_sums[val_i] == val_j) && (div_sums[val_j] == val_i)) begin
                                amicable_mark[val_i] <= 1'b1;
                                amicable_mark[val_j] <= 1'b1;
                            end
                            state <= VALIDATE;
                        end
                    end else begin
                        state <= SUM_UP;
                        curr_num <= 8'd2;
                        result <= 16'b0;
                    end
                end

                SUM_UP: begin
                    if (curr_num <= limit_reg) begin
                        if (amicable_mark[curr_num]) begin
                            result <= result + curr_num;
                        end
                        curr_num <= curr_num + 1;
                        state <= SUM_UP;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or new start (implicitly by IDLE transition on next start)
                    // But specs say "Wait for reset". Usually this implies staying here.
                    // However, if start goes low, we should ideally stay here until reset.
                    // To allow restarting, we might check if start is low.
                    if (!rst_n) begin // If reset goes low, handled by top reset block
                        // handled
                    end else if (start) begin
                        // If start is still high, maybe stay? Spec says "Wait for reset".
                        // We will stay in DONE until rst_n or maybe if we want to restart on falling edge of start?
                        // Let's stay in DONE as per "Wait for reset".
                        state <= DONE;
                    end else begin
                         // To be robust, if user wants to restart, they lower start, then raise start.
                         // But strict "Wait for reset" means ignore start.
                         // We will just stay here.
                         state <= DONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule