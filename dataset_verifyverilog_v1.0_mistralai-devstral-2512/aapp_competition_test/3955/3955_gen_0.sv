module max_bitwise_or_after_multiply(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] arr [0:7],
    input wire [3:0] k,
    input wire [3:0] x,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_POWER = 3'd1;
    localparam [2:0] COMPUTE_LEFT_OR = 3'd2;
    localparam [2:0] COMPUTE_RIGHT_OR = 3'd3;
    localparam [2:0] COMPUTE_CANDIDATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] x_power;
    reg [31:0] left_OR;
    reg [31:0] right_OR;
    reg [31:0] current_candidate;
    reg [31:0] max_candidate;
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd400;

    // Compute x^k using iterative multiplication
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_power <= 32'd0;
            left_OR <= 32'd0;
            right_OR <= 32'd0;
            current_candidate <= 32'd0;
            max_candidate <= 32'd0;
            i <= 3'd0;
            j <= 3'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_POWER;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_POWER: begin
                    // Compute x^k
                    if (k == 4'd0) begin
                        x_power <= 32'd1;
                        next_state <= COMPUTE_LEFT_OR;
                    end else begin
                        reg [31:0] temp_power;
                        reg [3:0] count;
                        temp_power <= 32'd1;
                        for (count = 0; count < k; count = count + 1) begin
                            temp_power <= temp_power * x;
                        end
                        x_power <= temp_power;
                        next_state <= COMPUTE_LEFT_OR;
                    end
                end

                COMPUTE_LEFT_OR: begin
                    // Compute left_OR for current i
                    if (i == 3'd0) begin
                        left_OR <= 32'd0;
                        next_state <= COMPUTE_RIGHT_OR;
                    end else begin
                        reg [31:0] temp_left;
                        temp_left <= 32'd0;
                        for (j = 0; j < i; j = j + 1) begin
                            temp_left <= temp_left | arr[j];
                        end
                        left_OR <= temp_left;
                        next_state <= COMPUTE_RIGHT_OR;
                    end
                end

                COMPUTE_RIGHT_OR: begin
                    // Compute right_OR for current i
                    if (i == 3'd7) begin
                        right_OR <= 32'd0;
                        next_state <= COMPUTE_CANDIDATE;
                    end else begin
                        reg [31:0] temp_right;
                        temp_right <= 32'd0;
                        for (j = i + 1; j < 8; j = j + 1) begin
                            temp_right <= temp_right | arr[j];
                        end
                        right_OR <= temp_right;
                        next_state <= COMPUTE_CANDIDATE;
                    end
                end

                COMPUTE_CANDIDATE: begin
                    // Compute candidate for current i
                    reg [31:0] temp_candidate;
                    temp_candidate <= left_OR | (arr[i] * x_power) | right_OR;
                    current_candidate <= temp_candidate;

                    // Update max_candidate
                    if (current_candidate > max_candidate) begin
                        max_candidate <= current_candidate;
                    end

                    // Move to next i
                    if (i == 3'd7) begin
                        next_state <= FINISH;
                    end else begin
                        i <= i + 3'd1;
                        next_state <= COMPUTE_LEFT_OR;
                    end
                end

                FINISH: begin
                    result <= max_candidate;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule