module order_by_points(
    input clk,
    input rst_n,
    input start,
    input [4:0] count,
    input signed [15:0] nums [0:7],
    output reg [4:0] done_count,
    output reg signed [15:0] result [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_PAIR = 3'b001; //专门的加载状态，解决非阻塞赋值读取问题
    localparam CALCULATE = 3'b010;
    localparam COMPARE = 3'b011;
    localparam SWAP = 3'b100;
    localparam INC_INDEX = 3'b101;
    localparam NEXT_PASS = 3'b110;
    localparam DONE = 3'b111;

    reg [2:0] state;
    reg [3:0] i; // Pass index (0 to count-2)
    reg [3:0] j; // Compare index (0 to count-2-i)
    reg [4:0] current_count;
    
    reg signed [15:0] val_a;
    reg signed [15:0] val_b;
    reg signed [5:0] sum_a;
    reg signed [5:0] sum_b;
    
    reg [15:0] digit_temp;
    reg [3:0] digit_step; // 0=load_a, 1..5=calc_a, 6=load_b, 7..11=calc_b
    
    reg signed [15:0] working_arr [0:7];
    reg swap_flag;
    
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            done_count <= 5'b0;
            i <= 4'd0;
            j <= 4'd0;
            digit_step <= 4'd0;
            sum_a <= 6'sd0;
            sum_b <= 6'sd0;
            for (k = 0; k < 8; k = k + 1) begin
                working_arr[k] <= 16'sd0;
                result[k] <= 16'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_count <= count;
                        // Copy input to working array
                        for (k = 0; k < 8; k = k + 1) begin
                            if (k < count) working_arr[k] <= nums[k];
                            else working_arr[k] <= 16'sd0;
                        end
                        if (count > 1) begin
                            i <= 4'd0;
                            j <= 4'd0;
                            state <= LOAD_PAIR;
                        end else begin
                            // 0 or 1 element is already sorted
                            done_count <= count;
                            for (k = 0; k < 8; k = k + 1) result[k] <= nums[k];
                            state <= DONE;
                        end
                    end
                end

                LOAD_PAIR: begin
                    // Load pair (j, j+1) from working_arr
                    val_a <= working_arr[j];
                    val_b <= working_arr[j+1];
                    digit_step <= 4'd0;
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    // Digit sum FSM
                    if (digit_step == 4'd0) begin
                        // Prepare A
                        digit_temp <= (val_a[15] ? -val_a : val_a);
                        sum_a <= 6'sd0;
                        digit_step <= 4'd1;
                    end else if (digit_step <= 4'd5) begin
                        // Process A (4 steps for max 5 digits, 1 step for init is separate or overlapped)
                        // Actually max 32767 -> 5 digits. 
                        // Cycle 1: %10, /10. Cycle 2: ... Cycle 5: 0.
                        // So steps 1..5 are sufficient.
                        if (digit_temp == 16'd0) begin
                            // Finished A early, switch to B setup
                            digit_step <= 4'd6; 
                        end else begin
                            sum_a <= sum_a + digit_temp % 10;
                            digit_temp <= digit_temp / 10;
                            if (digit_step == 4'd5) digit_step <= 4'd6; // Max reached
                            else digit_step <= digit_step + 1;
                        end
                    end else if (digit_step == 4'd6) begin
                        // Setup B
                        digit_temp <= (val_b[15] ? -val_b : val_b);
                        sum_b <= 6'sd0;
                        digit_step <= 4'd7;
                    end else if (digit_step <= 4'd11) begin
                        // Process B
                        if (digit_temp == 16'd0) begin
                            digit_step <= 4'd12; // Done
                        end else begin
                            sum_b <= sum_b + digit_temp % 10;
                            digit_temp <= digit_temp / 10;
                            if (digit_step == 4'd11) digit_step <= 4'd12;
                            else digit_step <= digit_step + 1;
                        end
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare sums
                    if (sum_a > sum_b) swap_flag <= 1'b1;
                    else swap_flag <= 1'b0;
                    state <= SWAP;
                end

                SWAP: begin
                    if (swap_flag) begin
                        // Swap in working array
                        working_arr[j] <= val_b;
                        working_arr[j+1] <= val_a;
                    end
                    // No matter swap or not, move to next index
                    state <= INC_INDEX;
                end

                INC_INDEX: begin
                    // Increment j
                    if (j < current_count - 2 - i) begin
                        j <= j + 1;
                        state <= LOAD_PAIR; // Go load next pair
                    end else begin
                        // End of pass
                        state <= NEXT_PASS;
                    end
                end

                NEXT_PASS: begin
                    // Increment i
                    if (i < current_count - 2) begin
                        i <= i + 1;
                        j <= 4'd0;
                        state <= LOAD_PAIR;
                    end else begin
                        // Finished all passes
                        done_count <= current_count;
                        for (k = 0; k < 8; k = k + 1) result[k] <= working_arr[k];
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule