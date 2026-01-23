module pack_consecutive_duplicates (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [4:0] input_len,
    output reg [7:0] out_arr [0:15],
    output reg [4:0] out_len,
    output reg done,
    output reg error
);

    // State machine declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] READ_INPUT   = 3'd1;
    localparam [2:0] PROCESS_RUN  = 3'd2;
    localparam [2:0] WRITE_OUTPUT = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Run tracking registers
    reg [7:0] current_value;
    reg [3:0] run_length;
    reg [4:0] input_index;
    reg [4:0] output_index;
    reg [4:0] group_count;
    reg [7:0] group_buffer [0:7];
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            input_index <= 5'd0;
            output_index <= 5'd0;
            run_length <= 4'd0;
            out_len <= 5'd0;
            current_value <= 8'd0;
            group_count <= 5'd0;
            cycle_count <= 8'd0;
            // Initialize group_buffer
            group_buffer[0] <= 8'd0;
            group_buffer[1] <= 8'd0;
            group_buffer[2] <= 8'd0;
            group_buffer[3] <= 8'd0;
            group_buffer[4] <= 8'd0;
            group_buffer[5] <= 8'd0;
            group_buffer[6] <= 8'd0;
            group_buffer[7] <= 8'd0;
            // Initialize out_arr
            out_arr[0] <= 8'd0; out_arr[1] <= 8'd0; out_arr[2] <= 8'd0; out_arr[3] <= 8'd0;
            out_arr[4] <= 8'd0; out_arr[5] <= 8'd0; out_arr[6] <= 8'd0; out_arr[7] <= 8'd0;
            out_arr[8] <= 8'd0; out_arr[9] <= 8'd0; out_arr[10] <= 8'd0; out_arr[11] <= 8'd0;
            out_arr[12] <= 8'd0; out_arr[13] <= 8'd0; out_arr[14] <= 8'd0; out_arr[15] <= 8'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    input_index <= 5'd0;
                    output_index <= 5'd0;
                    run_length <= 4'd0;
                    out_len <= 5'd0;
                    group_count <= 5'd0;
                    cycle_count <= 8'd0;
                    // Initialize out_arr
                    out_arr[0] <= 8'd0; out_arr[1] <= 8'd0; out_arr[2] <= 8'd0; out_arr[3] <= 8'd0;
                    out_arr[4] <= 8'd0; out_arr[5] <= 8'd0; out_arr[6] <= 8'd0; out_arr[7] <= 8'd0;
                    out_arr[8] <= 8'd0; out_arr[9] <= 8'd0; out_arr[10] <= 8'd0; out_arr[11] <= 8'd0;
                    out_arr[12] <= 8'd0; out_arr[13] <= 8'd0; out_arr[14] <= 8'd0; out_arr[15] <= 8'd0;
                    
                    if (start) begin
                        if (input_len > 5'd0 && input_len <= 5'd16) begin
                            current_state <= READ_INPUT;
                        end else begin
                            // Invalid input length
                            error <= 1'b1;
                            current_state <= FINISH;
                        end
                    end
                end
                
                READ_INPUT: begin
                    if (input_index < input_len) begin
                        if (input_index == 5'd0) begin
                            // First element
                            current_value <= arr[0];
                            run_length <= 4'd1;
                            group_buffer[0] <= arr[0];
                            input_index <= 5'd1;
                        end else begin
                            // Compare with previous
                            if (arr[input_index] == current_value) begin
                                // Continue current run
                                if (run_length < 4'd8) begin
                                    run_length <= run_length + 4'd1;
                                    group_buffer[run_length] <= arr[input_index];
                                    input_index <= input_index + 5'd1;
                                end else begin
                                    // Run too long (>8 elements)
                                    error <= 1'b1;
                                    current_state <= FINISH;
                                end
                            end else begin
                                // New run detected, process current one
                                current_state <= WRITE_OUTPUT;
                            end
                        end
                    end else begin
                        // End of input, process last run
                        current_state <= WRITE_OUTPUT;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                WRITE_OUTPUT: begin
                    // Write current group to output array
                    if (output_index < 5'd16) begin
                        // Store run length first
                        out_arr[output_index] <= run_length;
                        output_index <= output_index + 5'd1;
                        
                        // Store elements
                        // Use a for-loop to copy group_buffer elements
                        for (integer i = 0; i < 8; i++) begin
                            if (i < run_length && (output_index + 5'd1 + i) < 5'd16) begin
                                out_arr[output_index + 5'd1 + i] <= group_buffer[i];
                            end
                        end
                        
                        output_index <= output_index + 5'd1 + run_length;
                        out_len <= out_len + 5'd1;
                        
                        // Move to next run or finish
                        if (input_index < input_len) begin
                            // Setup for next run
                            current_value <= arr[input_index];
                            run_length <= 4'd1;
                            group_buffer[0] <= arr[input_index];
                            input_index <= input_index + 5'd1;
                            current_state <= READ_INPUT;
                        end else begin
                            current_state <= FINISH;
                        end
                    end else begin
                        // Output buffer full
                        error <= 1'b1;
                        current_state <= FINISH;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (start) begin
                        current_state <= IDLE;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
            
            // Cycle counter timeout
            if (cycle_count >= MAX_CYCLES) begin
                error <= 1'b1;
                current_state <= FINISH;
            end
        end
    end
endmodule