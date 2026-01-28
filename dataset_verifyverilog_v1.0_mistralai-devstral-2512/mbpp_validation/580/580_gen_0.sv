module even_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] data_in [0:7],
    input wire [2:0] depth,
    output reg signed [7:0] data_out [0:7],
    output reg [3:0] count_out,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SCAN    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Stack structure: index (3 bits), depth (3 bits), valid flag
    reg [2:0] stack_index [0:3];
    reg [2:0] stack_depth [0:3];
    reg stack_valid [0:3];
    reg [1:0] stack_ptr;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    reg [2:0] current_index;
    reg [2:0] current_depth;
    reg [2:0] output_index;
    reg [3:0] output_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            count_out <= 4'd0;
            
            // Initialize data_out array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                data_out[i] <= 8'd0;
            end
            
            // Initialize stack
            stack_ptr <= 2'd0;
            for (i = 0; i < 4; i = i + 1) begin
                stack_index[i] <= 3'd0;
                stack_depth[i] <= 3'd0;
                stack_valid[i] <= 1'b0;
            end
            
            current_index <= 3'd0;
            current_depth <= 3'd0;
            output_index <= 3'd0;
            output_count <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= SCAN;
                        current_index <= 3'd0;
                        current_depth <= 3'd0;
                        output_index <= 3'd0;
                        output_count <= 4'd0;
                        stack_ptr <= 2'd0;
                        
                        // Reset stack
                        integer i;
                        for (i = 0; i < 4; i = i + 1) begin
                            stack_valid[i] <= 1'b0;
                        end
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all elements or reached max cycles
                    if (current_index >= 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Check current element
                        if (data_in[current_index] == 8'sd255) begin
                            // Start of nested tuple
                            if (stack_ptr < 2'd3) begin
                                stack_index[stack_ptr] <= current_index;
                                stack_depth[stack_ptr] <= current_depth;
                                stack_valid[stack_ptr] <= 1'b1;
                                stack_ptr <= stack_ptr + 2'd1;
                                current_depth <= current_depth + 3'd1;
                            end
                            current_index <= current_index + 3'd1;
                        end else if (data_in[current_index] == 8'sd254) begin
                            // End of nested tuple
                            if (stack_ptr > 2'd0) begin
                                stack_ptr <= stack_ptr - 2'd1;
                                current_depth <= stack_depth[stack_ptr];
                            end
                            current_index <= current_index + 3'd1;
                        end else if (data_in[current_index][0] == 1'b0) begin
                            // Even number found
                            state <= PROCESS;
                        end else begin
                            // Odd number - skip
                            current_index <= current_index + 3'd1;
                        end
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Add even number to output if we have space
                    if (output_count < 4'd8) begin
                        data_out[output_index] <= data_in[current_index];
                        output_index <= output_index + 3'd1;
                        output_count <= output_count + 4'd1;
                    end
                    
                    current_index <= current_index + 3'd1;
                    state <= SCAN;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Add nesting markers to output
                    integer i;
                    reg [2:0] temp_ptr;
                    
                    for (i = 0; i < 4; i = i + 1) begin
                        if (stack_valid[i] && output_count < 4'd8) begin
                            // Add start marker
                            data_out[output_index] <= 8'sd255;
                            output_index <= output_index + 3'd1;
                            output_count <= output_count + 4'd1;
                        end
                    end
                    
                    // Reverse order for end markers
                    for (i = 3; i >= 0; i = i - 1) begin
                        if (stack_valid[i] && output_count < 4'd8) begin
                            // Add end marker
                            data_out[output_index] <= 8'sd254;
                            output_index <= output_index + 3'd1;
                            output_count <= output_count + 4'd1;
                        end
                    end
                    
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    count_out <= output_count;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end
endmodule