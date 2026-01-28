module filter_positive(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] data [0:7],
    input [3:0] length,
    output reg signed [7:0] result [0:7],
    output reg [3:0] result_len,
    output reg [7:0] valid_mask,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            input_index <= 4'd0;
            output_index <= 4'd0;
            result_len <= 4'd0;
            valid_mask <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize result array
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        input_index <= 4'd0;
                        output_index <= 4'd0;
                        result_len <= 4'd0;
                        valid_mask <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (input_index < length) begin
                        if (data[input_index] > 8'd0) begin
                            result[output_index] <= data[input_index];
                            output_index <= output_index + 4'd1;
                        end
                        input_index <= input_index + 4'd1;
                    end

                    if (input_index >= length || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        result_len <= output_index;
                        // Set valid_mask bits
                        valid_mask <= {8{1'b0}};
                        if (output_index > 4'd0) begin
                            valid_mask[0] <= 1'b1;
                            if (output_index > 4'd1) begin
                                valid_mask[1] <= 1'b1;
                                if (output_index > 4'd2) begin
                                    valid_mask[2] <= 1'b1;
                                    if (output_index > 4'd3) begin
                                        valid_mask[3] <= 1'b1;
                                        if (output_index > 4'd4) begin
                                            valid_mask[4] <= 1'b1;
                                            if (output_index > 4'd5) begin
                                                valid_mask[5] <= 1'b1;
                                                if (output_index > 4'd6) begin
                                                    valid_mask[6] <= 1'b1;
                                                    if (output_index > 4'd7) begin
                                                        valid_mask[7] <= 1'b1;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                FINISH: begin
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