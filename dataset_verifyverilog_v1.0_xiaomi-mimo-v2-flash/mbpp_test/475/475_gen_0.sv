module kv_sorter (
    input wire clk,
    input wire rst_n,
    input wire start,
    // 8 input pairs
    input wire [31:0] key_in [0:7],
    input wire signed [15:0] value_in [0:7],
    input wire valid_in [0:7],
    // 8 output pairs
    output reg [31:0] key_out [0:7],
    output reg signed [15:0] value_out [0:7],
    output reg valid_out [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CAPTURE    = 3'd1;
    localparam [2:0] INIT_SORT  = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] SWAP       = 3'd4;
    localparam [2:0] NEXT_PASS  = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state, next_state;
    
    // Internal buffers (8 slots)
    reg [31:0] buf_key [0:7];
    reg signed [15:0] buf_value [0:7];
    reg buf_valid [0:7];
    
    // Sorting indices
    reg [3:0] outer_idx;      // Outer loop index (0 to 6)
    reg [3:0] inner_idx;      // Inner loop index (0 to outer_idx-1)
    reg [3:0] swap_idx;       // For swap operation
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Swap temp storage
    reg [31:0] temp_key;
    reg signed [15:0] temp_value;
    reg temp_valid;
    
    integer i;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPTURE;
                end
            end
            CAPTURE: begin
                next_state = INIT_SORT;
            end
            INIT_SORT: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                // Check if comparison needed
                if (outer_idx >= 3'd7) begin
                    next_state = FINISH;
                end else if (buf_valid[inner_idx] && buf_valid[inner_idx + 1] && (buf_value[inner_idx + 1] > buf_value[inner_idx])) begin
                    next_state = SWAP;
                end else begin
                    next_state = NEXT_PASS;
                end
            end
            SWAP: begin
                if (inner_idx == outer_idx) begin
                    next_state = NEXT_PASS;
                end else begin
                    next_state = COMPARE;
                end
            end
            NEXT_PASS: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (outer_idx >= 3'd6) begin
                    next_state = FINISH;
                end else begin
                    next_state = INIT_SORT;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (i = 0; i < 8; i = i + 1) begin
                buf_key[i] <= 32'd0;
                buf_value[i] <= 16'sd0;
                buf_valid[i] <= 1'b0;
                key_out[i] <= 32'd0;
                value_out[i] <= 16'sd0;
                valid_out[i] <= 1'b0;
            end
            outer_idx <= 4'd0;
            inner_idx <= 4'd0;
            swap_idx <= 4'd0;
            cycle_count <= 8'd0;
            temp_key <= 32'd0;
            temp_value <= 16'sd0;
            temp_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0; // Default: done is 0
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                CAPTURE: begin
                    // Capture all inputs into internal buffers
                    for (i = 0; i < 8; i = i + 1) begin
                        buf_key[i] <= key_in[i];
                        buf_value[i] <= value_in[i];
                        buf_valid[i] <= valid_in[i];
                    end
                    // Initialize output buffers (default invalid)
                    for (i = 0; i < 8; i = i + 1) begin
                        key_out[i] <= 32'd0;
                        value_out[i] <= 16'sd0;
                        valid_out[i] <= 1'b0;
                    end
                end
                
                INIT_SORT: begin
                    // Start new outer pass
                    outer_idx <= outer_idx + 4'd1;
                    inner_idx <= outer_idx;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                COMPARE: begin
                    // Comparison logic handled in next_state
                    // If we need to swap, SWAP state will handle it
                end
                
                SWAP: begin
                    // Swap buf[inner_idx] and buf[inner_idx+1]
                    temp_key <= buf_key[inner_idx];
                    temp_value <= buf_value[inner_idx];
                    temp_valid <= buf_valid[inner_idx];
                    
                    buf_key[inner_idx] <= buf_key[inner_idx + 1];
                    buf_value[inner_idx] <= buf_value[inner_idx + 1];
                    buf_valid[inner_idx] <= buf_valid[inner_idx + 1];
                    
                    buf_key[inner_idx + 1] <= temp_key;
                    buf_value[inner_idx + 1] <= temp_value;
                    buf_valid[inner_idx + 1] <= temp_valid;
                    
                    inner_idx <= inner_idx + 4'd1;
                end
                
                NEXT_PASS: begin
                    // Done with current outer pass, reset inner_idx for next
                    inner_idx <= outer_idx;
                end
                
                FINISH: begin
                    // Copy sorted buffer to outputs
                    for (i = 0; i < 8; i = i + 1) begin
                        key_out[i] <= buf_key[i];
                        value_out[i] <= buf_value[i];
                        valid_out[i] <= buf_valid[i];
                    end
                    done <= 1'b1;
                    // Reset loop indices for next operation
                    outer_idx <= 4'd0;
                    inner_idx <= 4'd0;
                end
                
                default: begin
                    // Reset to safe state
                    outer_idx <= 4'd0;
                    inner_idx <= 4'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule