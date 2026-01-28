module LargestElementFinder(
    input clk,
    input rst_n,
    input valid_in,
    input start,
    input [15:0] arr [0:7],
    output reg [15:0] result,
    output reg done,
    output reg no_solution
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CAPTURE   = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [15:0] captured_arr [0:7];
    reg [15:0] best_d;
    reg found;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Index counters for nested loops
    reg [2:0] i, j, k, l;
    reg i_done, j_done, k_done;

    // Capture input data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            no_solution <= 1'b0;
            result <= 16'd0;
            cycle_count <= 10'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            l <= 3'd0;
            i_done <= 1'b0;
            j_done <= 1'b0;
            k_done <= 1'b0;
            found <= 1'b0;
            best_d <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        no_solution = 1'b0;

        case (state)
            IDLE: begin
                if (valid_in && start) begin
                    next_state = CAPTURE;
                end
            end

            CAPTURE: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done = 1'b1;
                no_solution = !found;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Capture input data on CAPTURE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                captured_arr[idx] <= 16'd0;
            end
        end else if (state == CAPTURE) begin
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                captured_arr[idx] <= arr[idx];
            end
        end
    end

    // Index generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            l <= 3'd0;
            i_done <= 1'b0;
            j_done <= 1'b0;
            k_done <= 1'b0;
            cycle_count <= 10'd0;
        end else if (state == COMPUTE) begin
            cycle_count <= cycle_count + 10'd1;

            // Increment l
            if (!k_done) begin
                l <= l + 3'd1;
                if (l == 3'd7) begin
                    l <= 3'd0;
                    k_done = 1'b1;
                end
            end
            // Increment k
            else if (k_done && !j_done) begin
                k <= k + 3'd1;
                if (k == 3'd6) begin
                    k <= 3'd0;
                    k_done = 1'b0;
                    j_done = 1'b1;
                end else begin
                    l <= k + 3'd1;
                    k_done = 1'b0;
                end
            end
            // Increment j
            else if (j_done && !i_done) begin
                j <= j + 3'd1;
                if (j == 3'd5) begin
                    j <= 3'd0;
                    j_done = 1'b0;
                    i_done = 1'b1;
                end else begin
                    k <= j + 3'd1;
                    l <= k + 3'd1;
                    j_done = 1'b0;
                end
            end
            // Increment i
            else if (i_done) begin
                i <= i + 3'd1;
                if (i == 3'd4) begin
                    i <= 3'd0;
                    i_done = 1'b0;
                end else begin
                    j <= i + 3'd1;
                    k <= j + 3'd1;
                    l <= k + 3'd1;
                    i_done = 1'b0;
                end
            end
        end
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            best_d <= 16'd0;
            found <= 1'b0;
        end else if (state == COMPUTE) begin
            // Check distinctness
            if (i != j && i != k && i != l && j != k && j != l && k != l) begin
                // Calculate sum
                reg signed [15:0] sum;
                sum = captured_arr[i] + captured_arr[j] + captured_arr[k];
                
                // Check if sum equals d and d is greater than current best
                if (sum == captured_arr[l] && (captured_arr[l] > best_d || !found)) begin
                    best_d <= captured_arr[l];
                    found <= 1'b1;
                end
            end
        end else if (state == FINISH) begin
            result <= found ? best_d : 16'd0;
        end
    end

endmodule