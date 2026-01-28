module non_decreasing_array(
    input clk,
    input rst_n,
    input start,
    input signed [23:0] data_in,
    input data_valid,
    input array_end,
    output reg [5:0] op_count,
    output reg [5:0] op_x,
    output reg [5:0] op_y,
    output reg op_valid,
    output reg done
);

    // Constants
    localparam [5:0] MAX_N = 6'd50;
    localparam [5:0] IDLE = 6'd0;
    localparam [5:0] READ_INPUT = 6'd1;
    localparam [5:0] FIND_CRITICAL = 6'd2;
    localparam [5:0] GENERATE_OPS = 6'd3;
    localparam [5:0] OUTPUT_OPS = 6'd4;
    localparam [5:0] DONE_STATE = 6'd5;

    // Internal registers
    reg [5:0] state;
    reg [5:0] index;
    reg [5:0] array_size;
    reg [5:0] op_index;
    reg [5:0] critical_index;
    reg [5:0] current_x;
    reg [5:0] current_y;
    reg signed [23:0] critical_value;
    reg signed [23:0] array [0:49];
    reg signed [23:0] temp_array [0:49];
    reg [5:0] operation_count;
    reg [5:0] operation_x [0:99];
    reg [5:0] operation_y [0:99];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 6'd0;
            array_size <= 6'd0;
            op_index <= 6'd0;
            critical_index <= 6'd0;
            current_x <= 6'd0;
            current_y <= 6'd0;
            critical_value <= 24'd0;
            operation_count <= 6'd0;
            op_count <= 6'd0;
            op_x <= 6'd0;
            op_y <= 6'd0;
            op_valid <= 1'b0;
            done <= 1'b0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 50; i = i + 1) begin
                array[i] <= 24'd0;
                temp_array[i] <= 24'd0;
            end
            for (i = 0; i < 100; i = i + 1) begin
                operation_x[i] <= 6'd0;
                operation_y[i] <= 6'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    op_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= READ_INPUT;
                        index <= 6'd0;
                        array_size <= 6'd0;
                    end
                end

                READ_INPUT: begin
                    if (data_valid) begin
                        array[index] <= data_in;
                        index <= index + 6'd1;
                        if (array_end) begin
                            array_size <= index;
                            state <= FIND_CRITICAL;
                            index <= 6'd0;
                        end
                    end
                end

                FIND_CRITICAL: begin
                    // Find element with maximum absolute value
                    integer i;
                    reg signed [23:0] max_abs;
                    reg signed [23:0] abs_val;
                    
                    max_abs = 24'd0;
                    critical_index = 6'd0;
                    critical_value = 24'd0;
                    
                    for (i = 0; i < array_size; i = i + 1) begin
                        abs_val = (array[i] < 24'd0) ? -array[i] : array[i];
                        if (abs_val > max_abs) begin
                            max_abs = abs_val;
                            critical_index = i;
                            critical_value = array[i];
                        end
                    end
                    
                    // Copy array to temp_array
                    for (i = 0; i < array_size; i = i + 1) begin
                        temp_array[i] = array[i];
                    end
                    
                    state <= GENERATE_OPS;
                    operation_count = 6'd0;
                    op_index = 6'd0;
                end

                GENERATE_OPS: begin
                    // Generate operations based on critical element
                    integer i;
                    reg signed [23:0] critical_abs;
                    
                    critical_abs = (critical_value < 24'd0) ? -critical_value : critical_value;
                    
                    if (critical_value >= 24'd0) begin
                        // Critical element is positive
                        // Add critical_value to all negative elements
                        for (i = 0; i < array_size; i = i + 1) begin
                            if (temp_array[i] < 24'd0) begin
                                operation_x[operation_count] = i + 6'd1;
                                operation_y[operation_count] = critical_index + 6'd1;
                                operation_count = operation_count + 6'd1;
                                temp_array[i] = temp_array[i] + critical_value;
                            end
                        end
                        
                        // Left-to-right cumulative sum
                        for (i = 1; i < array_size; i = i + 1) begin
                            if (temp_array[i] < temp_array[i-1]) begin
                                operation_x[operation_count] = i + 6'd1;
                                operation_y[operation_count] = i;
                                operation_count = operation_count + 6'd1;
                                temp_array[i] = temp_array[i] + temp_array[i-1];
                            end
                        end
                    end else begin
                        // Critical element is negative
                        // Subtract critical_value from all positive elements (reverse order)
                        for (i = array_size - 1; i >= 0; i = i - 1) begin
                            if (temp_array[i] > 24'd0) begin
                                operation_x[operation_count] = i + 6'd1;
                                operation_y[operation_count] = critical_index + 6'd1;
                                operation_count = operation_count + 6'd1;
                                temp_array[i] = temp_array[i] - critical_value;
                            end
                        end
                        
                        // Right-to-left cumulative sum
                        for (i = array_size - 2; i >= 0; i = i - 1) begin
                            if (temp_array[i] < temp_array[i+1]) begin
                                operation_x[operation_count] = i + 6'd1;
                                operation_y[operation_count] = i + 6'd1 + 6'd1;
                                operation_count = operation_count + 6'd1;
                                temp_array[i] = temp_array[i] + temp_array[i+1];
                            end
                        end
                    end
                    
                    state <= OUTPUT_OPS;
                    op_index = 6'd0;
                end

                OUTPUT_OPS: begin
                    if (op_index < operation_count) begin
                        op_x <= operation_x[op_index];
                        op_y <= operation_y[op_index];
                        op_valid <= 1'b1;
                        op_index <= op_index + 6'd1;
                    end else begin
                        op_valid <= 1'b0;
                        op_count <= operation_count;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    op_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule