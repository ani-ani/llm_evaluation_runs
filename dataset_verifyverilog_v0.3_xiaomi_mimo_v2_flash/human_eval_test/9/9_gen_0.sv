module rolling_max (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input signed [15:0] data_in,
    input data_in_valid,
    input data_in_done,
    output reg signed [15:0] result,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE             = 3'd0;
    localparam [2:0] WAIT_FOR_START   = 3'd1;
    localparam [2:0] PROCESSING       = 3'd2;
    localparam [2:0] OUTPUT_RESULT    = 3'd3;
    localparam [2:0] FINISH           = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg signed [15:0] current_max;
    reg input_done_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_max <= 16'sd0;
            result <= 16'sd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            input_done_flag <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    input_done_flag <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= WAIT_FOR_START;
                    end
                end

                WAIT_FOR_START: begin
                    // Wait for first valid input
                    if (valid_in && data_in_valid) begin
                        current_max <= data_in;
                        result <= data_in;
                        valid_out <= 1'b1;
                        input_done_flag <= data_in_done;
                        cycle_count <= cycle_count + 8'd1;
                        state <= OUTPUT_RESULT;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (valid_in && data_in_valid) begin
                        // Update max and output
                        if (data_in > current_max) begin
                            current_max <= data_in;
                            result <= data_in;
                        end else begin
                            current_max <= current_max;
                            result <= current_max;
                        end
                        valid_out <= 1'b1;
                        input_done_flag <= data_in_done;
                        state <= OUTPUT_RESULT;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= FINISH;
                    end
                end

                OUTPUT_RESULT: begin
                    valid_out <= 1'b0;
                    if (input_done_flag) begin
                        state <= FINISH;
                    end else begin
                        state <= PROCESSING;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule