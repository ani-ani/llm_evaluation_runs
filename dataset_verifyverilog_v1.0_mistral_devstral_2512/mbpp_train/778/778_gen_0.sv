module pack_consecutive_duplicates (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],  // 16-element input array, 8-bit elements
    input wire [4:0] input_len,    // Number of valid elements (1-16)
    output reg [7:0] out_arr [0:15],  // Flattened output array
    output reg [4:0] out_len,      // Number of output groups
    output reg done,
    output reg error               // Error: run too long or too many groups
);

    // Internal state machine
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] WRITE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] current_state, next_state;
    
    // Run tracking registers
    reg [7:0] current_value;
    reg [3:0] run_length;      // Max run length = 8
    reg [4:0] input_index;     // Current input position
    reg [4:0] output_index;    // Current output position (element count)
    reg [4:0] group_count;     // Number of groups written
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            input_index <= 5'd0;
            output_index <= 5'd0;
            group_count <= 5'd0;
            run_length <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize output array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                out_arr[i] <= 8'd0;
            end
            out_len <= 5'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    input_index <= 5'd0;
                    output_index <= 5'd0;
                    group_count <= 5'd0;
                    run_length <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        if (input_len > 5'd0 && input_len <= 5'd16) begin
                            current_state <= READ;
                        end else begin
                            current_state <= DONE_STATE;
                            error <= 1'b1;
                        end
                    end
                end
                
                READ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        current_state <= DONE_STATE;
                        error <= 1'b1;
                    end else if (input_index == 5'd0) begin
                        // First element
                        current_value <= arr[0];
                        run_length <= 4'd1;
                        input_index <= 5'd1;
                        
                        if (input_index == input_len) begin
                            current_state <= WRITE;
                        end
                    end else if (input_index < input_len) begin
                        // Compare with previous
                        if (arr[input_index] == current_value && run_length < 4'd8) begin
                            // Continue current run
                            run_length <= run_length + 4'd1;
                            input_index <= input_index + 5'd1;
                            
                            if (input_index == input_len) begin
                                current_state <= WRITE;
                            end
                        end else if (arr[input_index] != current_value) begin
                            // New run detected, process current one
                            current_state <= WRITE;
                        end else begin
                            // Run too long
                            current_state <= DONE_STATE;
                            error <= 1'b1;
                        end
                    end else begin
                        // End of input, process last run
                        current_state <= WRITE;
                    end
                end
                
                WRITE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        current_state <= DONE_STATE;
                        error <= 1'b1;
                    end else if (output_index + run_length > 5'd16) begin
                        // Not enough space in output array
                        current_state <= DONE_STATE;
                        error <= 1'b1;
                    end else begin
                        // Write run length and elements
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < run_length) begin
                                out_arr[output_index + i] <= current_value;
                            end
                        end
                        
                        output_index <= output_index + run_length;
                        group_count <= group_count + 5'd1;
                        
                        // Move to next state
                        if (input_index < input_len) begin
                            current_state <= READ;
                            // Setup for next run
                            current_value <= arr[input_index];
                            run_length <= 4'd1;
                            input_index <= input_index + 5'd1;
                        end else begin
                            current_state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    out_len <= group_count;
                    
                    if (start) begin
                        current_state <= IDLE;
                    end
                end
                
                default: current_state <= IDLE;
            endcase
        end
    end
endmodule