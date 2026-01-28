module min_subarray_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire data_valid,
    input wire data_end,
    output reg [15:0] result,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg signed [15:0] current_sum;
    reg signed [15:0] min_sum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                if (data_end) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            current_sum <= 16'd0;
            min_sum <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_sum <= 16'd0;
                        min_sum <= 16'sd32767;  // 0x7FFF
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    result_valid <= 1'b0;
                    done <= 1'b0;

                    if (data_valid) begin
                        // Update current_sum
                        current_sum <= current_sum + $signed(data_in);

                        // Update min_sum if current_sum is smaller
                        if ($signed(current_sum) < $signed(min_sum)) begin
                            min_sum <= current_sum;
                        end

                        // Reset current_sum if it becomes positive
                        if ($signed(current_sum) > 16'd0) begin
                            current_sum <= 16'd0;
                        end
                    end

                    // Handle data_end
                    if (data_end) begin
                        result <= min_sum;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    result <= min_sum;
                end

                default: begin
                    state <= IDLE;
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule