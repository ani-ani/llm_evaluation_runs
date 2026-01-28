module rescale_unit(
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input [2:0] len,
    output reg [15:0] data_out,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] min_val, max_val;
    reg [15:0] input_buffer [0:4];
    reg [3:0] input_count;
    reg [3:0] output_count;
    reg [3:0] latency_count;
    reg [31:0] scale_factor;
    reg [31:0] temp_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            min_val <= 16'd0;
            max_val <= 16'd0;
            input_count <= 4'd0;
            output_count <= 4'd0;
            latency_count <= 4'd0;
            scale_factor <= 32'd0;
            temp_result <= 32'd0;
            data_out <= 16'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            // Initialize input buffer
            input_buffer[0] <= 16'd0;
            input_buffer[1] <= 16'd0;
            input_buffer[2] <= 16'd0;
            input_buffer[3] <= 16'd0;
            input_buffer[4] <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COLLECT;
                        input_count <= 4'd0;
                        min_val <= 16'd0;
                        max_val <= 16'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COLLECT: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    // Store input value
                    input_buffer[input_count] <= data_in;
                    
                    // Update min and max
                    if (input_count == 4'd0) begin
                        min_val <= data_in;
                        max_val <= data_in;
                    end else begin
                        if (data_in < min_val) begin
                            min_val <= data_in;
                        end
                        if (data_in > max_val) begin
                            max_val <= data_in;
                        end
                    end
                    
                    // Check if all inputs collected
                    if (input_count == len - 1) begin
                        next_state <= COMPUTE;
                        latency_count <= 4'd0;
                    end else begin
                        input_count <= input_count + 4'd1;
                        next_state <= COLLECT;
                    end
                end

                COMPUTE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    // Latency counter
                    if (latency_count == 4'd9) begin
                        // Calculate scale factor: 65536 / (max - min)
                        // Using iterative subtraction for division
                        reg [31:0] dividend;
                        reg [31:0] divisor;
                        reg [31:0] quotient;
                        reg [31:0] remainder;
                        reg [5:0] i;
                        
                        dividend <= 32'd65536;
                        divisor <= {16'd0, max_val - min_val};
                        quotient <= 32'd0;
                        remainder <= 32'd0;
                        
                        if (divisor != 32'd0) begin
                            for (i = 0; i < 32; i = i + 1) begin
                                remainder <= {remainder[30:0], dividend[31]};
                                dividend <= {dividend[30:0], 1'b0};
                                if (remainder >= divisor) begin
                                    remainder <= remainder - divisor;
                                    quotient[i] <= 1'b1;
                                end else begin
                                    quotient[i] <= 1'b0;
                                end
                            end
                        end else begin
                            quotient <= 32'd0;
                        end
                        
                        scale_factor <= quotient;
                        output_count <= 4'd0;
                        next_state <= OUTPUT;
                    end else begin
                        latency_count <= latency_count + 4'd1;
                        next_state <= COMPUTE;
                    end
                end

                OUTPUT: begin
                    // Calculate rescaled value: (val - min) * scale / 65536
                    temp_result <= {16'd0, input_buffer[output_count] - min_val} * scale_factor;
                    data_out <= temp_result[31:16]; // Divide by 65536 (shift right 16)
                    out_valid <= 1'b1;
                    done <= 1'b0;
                    
                    if (output_count == len - 1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        output_count <= output_count + 4'd1;
                        next_state <= OUTPUT;
                    end
                end

                DONE_STATE: begin
                    out_valid <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule