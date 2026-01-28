module RescaleUnit(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire arr_valid,
    input wire [2:0] len,
    input wire signed [15:0] arr_in [0:7],
    output reg result_valid,
    output reg signed [15:0] arr_out [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FIND_MINMAX = 3'd1;
    localparam [2:0] COMPUTE_SCALE = 3'd2;
    localparam [2:0] RESCALE   = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for min/max
    reg signed [15:0] min_val;
    reg signed [15:0] max_val;
    reg signed [15:0] scale;
    reg signed [31:0] scale_inv;  // 65536 / scale in Q16.16
    reg signed [15:0] temp_diff;
    reg signed [31:0] temp_mult;

    // Counter for array processing
    reg [2:0] idx;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            min_val <= 16'd0;
            max_val <= 16'd0;
            scale <= 16'd0;
            scale_inv <= 32'd0;
            temp_diff <= 16'd0;
            temp_mult <= 32'd0;
            idx <= 3'd0;

            // Initialize output array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                arr_out[i] <= 16'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && arr_valid) begin
                        next_state <= FIND_MINMAX;
                        // Initialize min/max with first element
                        min_val <= arr_in[0];
                        max_val <= arr_in[0];
                        idx <= 3'd1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_MINMAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < len) begin
                        // Compare current element
                        if (arr_in[idx] < min_val) begin
                            min_val <= arr_in[idx];
                        end
                        if (arr_in[idx] > max_val) begin
                            max_val <= arr_in[idx];
                        end
                        idx <= idx + 3'd1;
                        next_state <= FIND_MINMAX;
                    end else begin
                        next_state <= COMPUTE_SCALE;
                    end
                end

                COMPUTE_SCALE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute scale = max - min
                    scale <= max_val - min_val;

                    // Handle division by zero or reverse range
                    if (scale == 16'd0) begin
                        // All values same, output 0
                        scale_inv <= 32'd0;
                    end else if (max_val < min_val) begin
                        // Reverse range, swap min and max
                        temp_diff <= min_val;
                        min_val <= max_val;
                        max_val <= temp_diff;
                        scale <= max_val - min_val;
                        // Compute 65536 / scale in Q16.16
                        scale_inv <= (65536 << 16) / scale;
                    end else begin
                        // Normal case: compute 65536 / scale in Q16.16
                        scale_inv <= (65536 << 16) / scale;
                    end
                    next_state <= RESCALE;
                    idx <= 3'd0;
                end

                RESCALE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < len) begin
                        // Compute (value - min) * scale_inv
                        temp_diff <= arr_in[idx] - min_val;
                        temp_mult <= temp_diff * scale_inv;
                        // Shift right by 16 to get Q8.8 result
                        arr_out[idx] <= temp_mult[31:16];
                        // Clamp to Q8.8 range
                        if (arr_out[idx] > 16'd32767) begin
                            arr_out[idx] <= 16'd32767;
                        end else if (arr_out[idx] < 16'd(-32768)) begin
                            arr_out[idx] <= 16'd(-32768);
                        end
                        idx <= idx + 3'd1;
                        next_state <= RESCALE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

    // Ensure we don't exceed max cycles
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            next_state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
        end
    end

endmodule