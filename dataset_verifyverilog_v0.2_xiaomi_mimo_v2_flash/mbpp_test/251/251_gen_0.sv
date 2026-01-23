module insert_element (
    input clk,
    input rst_n,
    input start,
    input [7:0] element,
    input [7:0] list_data [0:7],
    input [2:0] list_len,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    
    reg [2:0] input_index; // Counter for input list
    reg [3:0] output_index; // Counter for output list
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (input_index == list_len && output_index == {list_len, 1'b0})
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                if (!rst_n)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic and counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs and counters
            for (int i = 0; i < 16; i++) begin
                result[i] <= 8'b0;
            end
            result_len <= 4'b0;
            done <= 1'b0;
            input_index <= 3'b0;
            output_index <= 4'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Reset counters and prepare for processing
                        input_index <= 3'b0;
                        output_index <= 4'b0;
                        done <= 1'b0;
                        result_len <= 4'b0;
                        // Reset result array (optional, but cleaner)
                        // result will be overwritten during processing
                    end
                end
                
                PROCESSING: begin
                    if (input_index < list_len) begin
                        // Check if we need to write the insert element
                        // We cycle: insert (out_idx even) -> original (out_idx odd)
                        if (output_index[0] == 1'b0) begin
                            // Even index: write insert element
                            result[output_index] <= element;
                            output_index <= output_index + 1;
                            // Don't increment input_index, we still need to write the original
                        end else begin
                            // Odd index: write original element
                            result[output_index] <= list_data[input_index];
                            output_index <= output_index + 1;
                            input_index <= input_index + 1;
                        end
                        // Update result_len to match the number of valid elements written
                        result_len <= output_index + 1;
                    end else begin
                        // Processing complete, waiting for state transition
                        result_len <= {list_len, 1'b0};
                    end
                end
                
                DONE: begin
                    // Hold result, ensure done is high
                    done <= 1'b1;
                    // Maintain result_len (already set in PROCESSING)
                end
            endcase
        end
    end

endmodule