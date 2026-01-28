module max_avg_subarray(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a_0,
    input wire [7:0] a_1,
    input wire [7:0] a_2,
    input wire [7:0] a_3,
    input wire [7:0] a_4,
    input wire [7:0] a_5,
    input wire [7:0] a_6,
    input wire [7:0] a_7,
    input wire [3:0] n,
    input wire [3:0] k,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] INIT = 5'd1;
    localparam [4:0] BINARY_SEARCH = 5'd2;
    localparam [4:0] CHECK_CONDITION = 5'd3;
    localparam [4:0] UPDATE_BOUNDS = 5'd4;
    localparam [4:0] FINISH = 5'd5;

    reg [4:0] state, next_state;

    // Binary search variables
    reg [31:0] low;
    reg [31:0] high;
    reg [31:0] mid;
    reg [4:0] iteration_count;

    // Check condition variables
    reg [31:0] prefix [0:8];
    reg [31:0] min_prefix;
    reg [3:0] i, j;
    reg condition_met;

    // Array conversion to Q16.16
    reg [31:0] a_q16 [0:7];

    // Convert input array to Q16.16
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_q16[0] <= 32'd0;
            a_q16[1] <= 32'd0;
            a_q16[2] <= 32'd0;
            a_q16[3] <= 32'd0;
            a_q16[4] <= 32'd0;
            a_q16[5] <= 32'd0;
            a_q16[6] <= 32'd0;
            a_q16[7] <= 32'd0;
        end else begin
            a_q16[0] <= {16'd0, a_0};
            a_q16[1] <= {16'd0, a_1};
            a_q16[2] <= {16'd0, a_2};
            a_q16[3] <= {16'd0, a_3};
            a_q16[4] <= {16'd0, a_4};
            a_q16[5] <= {16'd0, a_5};
            a_q16[6] <= {16'd0, a_6};
            a_q16[7] <= {16'd0, a_7};
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iteration_count <= 5'd0;
            condition_met <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            min_prefix <= 32'd0;
            prefix[0] <= 32'd0;
            prefix[1] <= 32'd0;
            prefix[2] <= 32'd0;
            prefix[3] <= 32'd0;
            prefix[4] <= 32'd0;
            prefix[5] <= 32'd0;
            prefix[6] <= 32'd0;
            prefix[7] <= 32'd0;
            prefix[8] <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = BINARY_SEARCH;
            end

            BINARY_SEARCH: begin
                if (iteration_count < 5'd32) begin
                    next_state = CHECK_CONDITION;
                end else begin
                    next_state = FINISH;
                end
            end

            CHECK_CONDITION: begin
                if (i < n) begin
                    next_state = CHECK_CONDITION;
                end else begin
                    next_state = UPDATE_BOUNDS;
                end
            end

            UPDATE_BOUNDS: begin
                next_state = BINARY_SEARCH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Binary search initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iteration_count <= 5'd0;
        end else if (state == INIT) begin
            low <= 32'd0;
            high <= {16'd255, 16'd0};
            iteration_count <= 5'd0;
        end else if (state == BINARY_SEARCH) begin
            mid <= (low + high) >>> 1;
        end
    end

    // Check condition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd0;
            j <= 4'd0;
            min_prefix <= 32'd0;
            condition_met <= 1'b0;
            prefix[0] <= 32'd0;
            prefix[1] <= 32'd0;
            prefix[2] <= 32'd0;
            prefix[3] <= 32'd0;
            prefix[4] <= 32'd0;
            prefix[5] <= 32'd0;
            prefix[6] <= 32'd0;
            prefix[7] <= 32'd0;
            prefix[8] <= 32'd0;
        end else if (state == CHECK_CONDITION) begin
            if (i == 4'd0) begin
                // Initialize prefix sums
                prefix[0] <= 32'd0;
                prefix[1] <= a_q16[0] - mid;
                prefix[2] <= prefix[1] + (a_q16[1] - mid);
                prefix[3] <= prefix[2] + (a_q16[2] - mid);
                prefix[4] <= prefix[3] + (a_q16[3] - mid);
                prefix[5] <= prefix[4] + (a_q16[4] - mid);
                prefix[6] <= prefix[5] + (a_q16[5] - mid);
                prefix[7] <= prefix[6] + (a_q16[6] - mid);
                prefix[8] <= prefix[7] + (a_q16[7] - mid);
                
                // Initialize min_prefix
                min_prefix <= prefix[0];
                j <= 4'd0;
                i <= k - 1'b1;
            end else begin
                // Update min_prefix for current window
                if (j < i - k + 1'b1) begin
                    if (prefix[j] < min_prefix) begin
                        min_prefix <= prefix[j];
                    end
                    j <= j + 1'b1;
                end else begin
                    // Check condition
                    if (prefix[i + 1'b1] - min_prefix >= 32'd0) begin
                        condition_met <= 1'b1;
                    end
                    i <= i + 1'b1;
                    j <= 4'd0;
                    min_prefix <= prefix[0];
                end
            end
        end
    end

    // Update bounds
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iteration_count <= 5'd0;
        end else if (state == UPDATE_BOUNDS) begin
            if (condition_met) begin
                low <= mid;
            end else begin
                high <= mid;
            end
            iteration_count <= iteration_count + 5'd1;
            condition_met <= 1'b0;
        end else if (state == FINISH) begin
            result <= low;
            done <= 1'b1;
        end else if (state == IDLE && start) begin
            done <= 1'b0;
        end
    end

endmodule