module filter_positive (
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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] input_idx;      // Current index in input array
    reg [3:0] output_idx;     // Current index in output array
    reg [3:0] process_count;  // Number of elements processed
    reg [3:0] result_len_next;
    reg [7:0] valid_mask_next;
    reg signed [7:0] result_next [0:7];
    reg [3:0] i;              // Loop variable for initialization

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (process_count >= length)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESS;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            valid_mask <= 8'd0;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            process_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'sd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset counters
                        input_idx <= 4'd0;
                        output_idx <= 4'd0;
                        process_count <= 4'd0;
                        result_len <= 4'd0;
                        valid_mask <= 8'd0;
                        // Clear result array
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 8'sd0;
                        end
                    end
                end
                
                PROCESS: begin
                    // Check if current element is positive (> 0)
                    if (data[input_idx] > 8'sd0) begin
                        // Store in result array
                        result[output_idx] <= data[input_idx];
                        // Increment output index
                        output_idx <= output_idx + 4'd1;
                        // Update result length
                        result_len <= result_len + 4'd1;
                        // Update valid mask
                        valid_mask <= valid_mask | (8'd1 << output_idx);
                    end
                    // Move to next input element
                    input_idx <= input_idx + 4'd1;
                    process_count <= process_count + 4'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule