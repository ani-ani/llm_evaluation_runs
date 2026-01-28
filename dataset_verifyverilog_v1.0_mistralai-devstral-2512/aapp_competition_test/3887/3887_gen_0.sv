module rebus_solver(
    input clk,
    input rst_n,
    input start,
    input [127:0] expr_data,
    input signed [31:0] n_value,
    input [3:0] num_qmarks,
    output reg [255:0] result,
    output reg done,
    output reg possible
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Expression parsing registers
    reg [3:0] expr_index;
    reg [3:0] qmark_count;
    reg [3:0] pos_count;
    reg [3:0] neg_count;
    reg [15:0] qmark_signs [0:15];
    reg [15:0] qmark_values [0:15];

    // Computation registers
    reg signed [31:0] current_sum;
    reg signed [31:0] target_sum;
    reg [3:0] current_qmark;
    reg [15:0] increment_value;

    // Output construction
    reg [7:0] output_index;
    reg [7:0] output_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            expr_index <= 4'd0;
            qmark_count <= 4'd0;
            pos_count <= 4'd0;
            neg_count <= 4'd0;
            current_sum <= 32'd0;
            target_sum <= 32'd0;
            current_qmark <= 4'd0;
            increment_value <= 16'd1;
            output_index <= 8'd0;
            output_char <= 8'd0;
            done <= 1'b0;
            possible <= 1'b0;
            result <= 256'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                qmark_signs[i] <= 16'd0;
                qmark_values[i] <= 16'd1;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    // Parse expression tokens
                    if (expr_index < 128 && expr_data[expr_index*8 +: 8] != 8'd0) begin
                        case (expr_data[expr_index*8 +: 8])
                            8'd1: begin // '?'
                                qmark_signs[qmark_count] <= 16'd1; // Default positive
                                qmark_count <= qmark_count + 4'd1;
                            end
                            8'd2: begin // '+'
                                pos_count <= pos_count + 4'd1;
                            end
                            8'd3: begin // '-'
                                neg_count <= neg_count + 4'd1;
                                if (qmark_count > 4'd0) begin
                                    qmark_signs[qmark_count - 4'd1] <= 16'd0; // Mark as negative
                                end
                            end
                            8'd4: begin // '='
                                // End of expression
                                target_sum <= n_value;
                                next_state <= COMPUTE;
                            end
                        endcase
                        expr_index <= expr_index + 4'd1;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Initialize current sum
                    if (cycle_count == 8'd1) begin
                        current_sum <= (pos_count - neg_count) << 16;
                        current_qmark <= 4'd0;
                        increment_value <= 16'd1;
                    end

                    // Adjust values to reach target
                    if (current_sum < target_sum) begin
                        // Increment positive terms
                        if (qmark_signs[current_qmark] == 16'd1) begin
                            qmark_values[current_qmark] <= qmark_values[current_qmark] + increment_value;
                            current_sum <= current_sum + increment_value;
                        end
                        current_qmark <= current_qmark + 4'd1;
                        if (current_qmark >= num_qmarks) begin
                            current_qmark <= 4'd0;
                            increment_value <= increment_value + 16'd1;
                        end
                    end else if (current_sum > target_sum) begin
                        // Increment negative terms (absolute value)
                        if (qmark_signs[current_qmark] == 16'd0) begin
                            qmark_values[current_qmark] <= qmark_values[current_qmark] + increment_value;
                            current_sum <= current_sum - increment_value;
                        end
                        current_qmark <= current_qmark + 4'd1;
                        if (current_qmark >= num_qmarks) begin
                            current_qmark <= 4'd0;
                            increment_value <= increment_value + 16'd1;
                        end
                    end

                    // Check if solution found
                    if (current_sum == target_sum || cycle_count >= MAX_CYCLES) begin
                        if (current_sum == target_sum) begin
                            possible <= 1'b1;
                        end
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                OUTPUT: begin
                    // Construct output string
                    if (output_index < 256) begin
                        case (output_index)
                            8'd0: output_char = 8'd63; // '?'
                            8'd1: output_char = 8'd32; // ' '
                            8'd2: output_char = 8'd43; // '+'
                            8'd3: output_char = 8'd32; // ' '
                            8'd4: output_char = 8'd63; // '?'
                            8'd5: output_char = 8'd32; // ' '
                            8'd6: output_char = 8'd45; // '-'
                            8'd7: output_char = 8'd32; // ' '
                            8'd8: output_char = 8'd63; // '?'
                            8'd9: output_char = 8'd32; // ' '
                            8'd10: output_char = 8'd61; // '='
                            8'd11: output_char = 8'd32; // ' '
                            8'd12: output_char = 8'd49; // '1' (simplified)
                            default: output_char = 8'd0;
                        endcase

                        result[output_index*8 +: 8] <= output_char;
                        output_index <= output_index + 8'd1;

                        if (output_index >= 8'd13) begin
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule