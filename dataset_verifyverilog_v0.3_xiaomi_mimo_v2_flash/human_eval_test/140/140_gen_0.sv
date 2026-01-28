module fix_spaces (
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:7],
    input [3:0] length,
    output reg [7:0] result [0:7],
    output reg [3:0] out_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CAPTURE    = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] FINISHED   = 2'd3;

    // FSM registers
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [7:0] input_text [0:7];
    reg [3:0] input_len;
    reg [3:0] proc_idx;
    reg [3:0] out_idx;
    reg [3:0] space_count;
    reg [3:0] cycle_counter;
    
    // ASCII constants
    localparam [7:0] SPACE = 8'h20;
    localparam [7:0] UNDERSCORE = 8'h5F;
    localparam [7:0] HYPHEN = 8'h2D;
    
    // Timing constant (12 cycles latency)
    localparam [3:0] LATENCY = 4'd12;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? CAPTURE : IDLE;
            CAPTURE:    next_state = PROCESSING;
            PROCESSING: next_state = (cycle_counter >= LATENCY) ? FINISHED : PROCESSING;
            FINISHED:   next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            out_len <= 4'd0;
            proc_idx <= 4'd0;
            out_idx <= 4'd0;
            space_count <= 4'd0;
            cycle_counter <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                input_text[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    out_len <= 4'd0;
                    space_count <= 4'd0;
                    out_idx <= 4'd0;
                    if (start) begin
                        // CAPTURE state will execute next cycle
                    end
                end
                
                CAPTURE: begin
                    // Latch input data
                    for (i = 0; i < 8; i = i + 1) begin
                        input_text[i] <= text[i];
                    end
                    input_len <= length;
                    proc_idx <= 4'd0;
                    // Clear result buffer
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= 8'd0;
                    end
                end
                
                PROCESSING: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Main processing logic
                    if (cycle_counter < input_len && proc_idx < 8'd8) begin
                        if (input_text[proc_idx] == SPACE) begin
                            space_count <= space_count + 4'd1;
                        end else begin
                            // Non-space character found
                            if (space_count == 4'd1) begin
                                // 1 space -> underscore
                                if (out_idx < 8'd8) begin
                                    result[out_idx] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end else if (space_count == 4'd2) begin
                                // 2 spaces -> two underscores
                                if (out_idx < 8'd7) begin
                                    result[out_idx] <= UNDERSCORE;
                                    result[out_idx + 4'd1] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd2;
                                end else if (out_idx < 8'd8) begin
                                    result[out_idx] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end else if (space_count > 4'd2) begin
                                // >2 spaces -> hyphen
                                if (out_idx < 8'd8) begin
                                    result[out_idx] <= HYPHEN;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end
                            
                            space_count <= 4'd0;
                            
                            // Write current character
                            if (out_idx < 8'd8) begin
                                result[out_idx] <= input_text[proc_idx];
                                out_idx <= out_idx + 4'd1;
                            end
                        end
                        
                        proc_idx <= proc_idx + 4'd1;
                    end
                    
                    // Handle end of string (remaining spaces)
                    if (cycle_counter >= input_len && cycle_counter < input_len + 4'd8) begin
                        if (space_count > 4'd0) begin
                            if (space_count == 4'd1) begin
                                if (out_idx < 8'd8) begin
                                    result[out_idx] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end else if (space_count == 4'd2) begin
                                if (out_idx < 8'd7) begin
                                    result[out_idx] <= UNDERSCORE;
                                    result[out_idx + 4'd1] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd2;
                                end else if (out_idx < 8'd8) begin
                                    result[out_idx] <= UNDERSCORE;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end else if (space_count > 4'd2) begin
                                if (out_idx < 8'd8) begin
                                    result[out_idx] <= HYPHEN;
                                    out_idx <= out_idx + 4'd1;
                                end
                            end
                            space_count <= 4'd0;
                        end
                    end
                    
                    // Update output length after processing is complete
                    if (cycle_counter >= LATENCY) begin
                        out_len <= out_idx;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Update state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule