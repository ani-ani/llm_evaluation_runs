module filter_odd_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire arr_in_valid,
    input wire signed [7:0] arr_in [0:7],
    output reg signed [7:0] arr_out [0:3],
    output reg [2:0] arr_out_len,
    output reg done
);

    // State declarations for sequential FSM
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] DONE      = 2'd2;
    
    // Registers and variables
    reg [1:0] state;
    reg [2:0] input_idx;      // Index into input array (0-7)
    reg [2:0] output_idx;     // Index into output array (0-3)
    reg [2:0] cycle_count;    // Prevent infinite loops
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_idx <= 3'd0;
            output_idx <= 3'd0;
            cycle_count <= 3'd0;
            done <= 1'b0;
            arr_out_len <= 3'd0;
            // Initialize output array
            arr_out[0] <= 8'sd0;
            arr_out[1] <= 8'sd0;
            arr_out[2] <= 8'sd0;
            arr_out[3] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    input_idx <= 3'd0;
                    output_idx <= 3'd0;
                    arr_out_len <= 3'd0;
                    // Initialize output array to zeros
                    arr_out[0] <= 8'sd0;
                    arr_out[1] <= 8'sd0;
                    arr_out[2] <= 8'sd0;
                    arr_out[3] <= 8'sd0;
                    
                    if (start && arr_in_valid) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Check current input element for oddness
                    if (output_idx < 4'd4 && input_idx < 4'd8) begin
                        // Check if element is odd (works for both positive and negative)
                        if (arr_in[input_idx][0] == 1'b1) begin
                            // Element is odd - store in output array
                            arr_out[output_idx] <= arr_in[input_idx];
                            output_idx <= output_idx + 3'd1;
                        end
                        
                        // Move to next input element
                        input_idx <= input_idx + 3'd1;
                    end
                    
                    // Completion conditions:
                    // 1. Processed all 8 input elements
                    // 2. Output array is full (4 elements)
                    // 3. Safety timeout (8 cycles max)
                    if (input_idx >= 4'd7 || output_idx >= 4'd4 || cycle_count >= 4'd7) begin
                        arr_out_len <= output_idx;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule