module RemoveConsecutiveDuplicates(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_data [0:15],
    input wire [3:0] input_len,
    output reg [7:0] output_data [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // State and control registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] input_idx;
    reg [3:0] output_idx;
    reg [7:0] prev_value;
    reg [7:0] buffer [0:15];
    reg processing_started;
    
    integer i;
    
    // FSM next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (processing_started && input_idx >= input_len) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // FSM state register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            output_len <= 4'd0;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            prev_value <= 8'd0;
            processing_started <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                output_data[i] <= 8'd0;
                buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    output_len <= 4'd0;
                    input_idx <= 4'd0;
                    output_idx <= 4'd0;
                    processing_started <= 1'b0;
                    if (start) begin
                        // Store input data in buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < input_len) begin
                                buffer[i] <= input_data[i];
                            end else begin
                                buffer[i] <= 8'd0;
                            end
                        end
                        // Initialize output buffer to zeros
                        for (i = 0; i < 16; i = i + 1) begin
                            output_data[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    processing_started <= 1'b1;
                    done <= 1'b0;
                    
                    if (input_idx < input_len) begin
                        if (input_idx == 4'd0) begin
                            // First element always included
                            output_data[output_idx] <= buffer[0];
                            output_len <= output_idx + 4'd1;
                            prev_value <= buffer[0];
                            input_idx <= input_idx + 4'd1;
                            output_idx <= output_idx + 4'd1;
                        end else begin
                            // Compare with previous element
                            if (buffer[input_idx] != prev_value) begin
                                // Different value, add to output
                                output_data[output_idx] <= buffer[input_idx];
                                output_len <= output_idx + 4'd1;
                                output_idx <= output_idx + 4'd1;
                            end
                            // Update previous value and increment input index
                            prev_value <= buffer[input_idx];
                            input_idx <= input_idx + 4'd1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Zero-pad any remaining positions
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i >= output_len) begin
                            output_data[i] <= 8'd0;
                        end
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    output_len <= 4'd0;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule