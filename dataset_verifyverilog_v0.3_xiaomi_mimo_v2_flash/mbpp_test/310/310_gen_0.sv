module StringToTupleConverter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    input load_valid,
    output reg [7:0] char_out,
    output reg [2:0] out_index,
    output reg valid_out,
    output reg done,
    output reg [3:0] count
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] input_memory [0:7];  // 8x8-bit storage
    reg [2:0] output_idx;           // Internal output index
    reg [3:0] filtered_count;       // Count of non-space chars
    reg [2:0] i;                    // Loop counter
    reg [7:0] temp_char;            // Temporary storage for processing
    reg processing_done;            // Flag for processing completion

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            out_index <= 3'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            output_idx <= 3'd0;
            filtered_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                input_memory[i] <= 8'd0;
            end
            temp_char <= 8'd0;
            processing_done <= 1'b0;
        end else begin
            // State transition
            state <= next_state;

            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    count <= 4'd0;
                    output_idx <= 3'd0;
                    filtered_count <= 4'd0;
                    processing_done <= 1'b0;
                    
                    // Load character if valid
                    if (load_valid) begin
                        input_memory[char_index] <= char_in;
                    end
                    
                    // Reset inputs on start
                    if (start) begin
                        char_out <= 8'd0;
                        out_index <= 3'd0;
                    end
                end

                LOAD: begin
                    // This state is automatically entered on start
                    // Processing happens in OUTPUT state
                    // Filter and count characters
                    filtered_count <= 4'd0;
                    output_idx <= 3'd0;
                end

                OUTPUT: begin
                    if (!processing_done) begin
                        // Find next non-space character
                        if (output_idx < 8 && input_memory[output_idx] != 8'd32) begin
                            char_out <= input_memory[output_idx];
                            out_index <= output_idx;
                            valid_out <= 1'b1;
                            filtered_count <= filtered_count + 4'd1;
                        end
                        output_idx <= output_idx + 3'd1;
                        
                        // Check if we've processed all positions
                        if (output_idx >= 7) begin
                            processing_done <= 1'b1;
                        end
                    end else begin
                        // After processing all positions
                        valid_out <= 1'b0;
                        count <= filtered_count;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    char_out <= 8'd0;
                    out_index <= 3'd0;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    count <= 4'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = OUTPUT;  // Start processing immediately
                end else begin
                    next_state = IDLE;
                end
            end

            OUTPUT: begin
                // Output for 8 cycles, then go to done
                if (processing_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUTPUT;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule