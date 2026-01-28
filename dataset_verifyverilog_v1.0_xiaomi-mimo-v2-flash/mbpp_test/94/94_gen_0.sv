module TupleFinder (
    input clk,
    input rst_n,
    input start,
    input data_valid,
    input [63:0] tuple_str [0:15],
    input [15:0] tuple_val [0:15],
    input [4:0] valid_tuples,
    output reg [63:0] result_str,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPARE  = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] DONE     = 3'd4;
    localparam [2:0] ERROR    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_min_val;
    reg [3:0] current_min_idx;
    reg [3:0] scan_idx;
    reg [7:0] timeout_counter;
    reg [63:0] temp_result_str;
    
    // Timeout threshold (256 cycles max)
    localparam [7:0] TIMEOUT_MAX = 8'd255;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_str <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
            current_min_val <= 16'd65535;
            current_min_idx <= 4'd0;
            scan_idx <= 4'd0;
            timeout_counter <= 8'd0;
            temp_result_str <= 64'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    timeout_counter <= 8'd0;
                    // Initialize min registers
                    current_min_val <= 16'd65535;
                    current_min_idx <= 4'd0;
                    
                    if (start && data_valid) begin
                        if (valid_tuples > 5'd0) begin
                            scan_idx <= 4'd0;
                        end
                    end
                end
                
                LOAD: begin
                    // Reset min value for new scan
                    current_min_val <= 16'd65535;
                    current_min_idx <= 4'd0;
                    scan_idx <= 4'd0;
                    timeout_counter <= timeout_counter + 8'd1;
                end
                
                COMPARE: begin
                    timeout_counter <= timeout_counter + 8'd1;
                    
                    // Check if current tuple is valid and has smaller value
                    if (scan_idx < valid_tuples[3:0]) begin
                        if (tuple_val[scan_idx] < current_min_val) begin
                            current_min_val <= tuple_val[scan_idx];
                            current_min_idx <= scan_idx;
                        end
                    end
                    
                    // Increment scan index
                    if (scan_idx < 4'd15) begin
                        scan_idx <= scan_idx + 4'd1;
                    end
                end
                
                UPDATE: begin
                    timeout_counter <= timeout_counter + 8'd1;
                    // Load result string from the winning tuple
                    temp_result_str <= tuple_str[current_min_idx];
                end
                
                DONE: begin
                    result_str <= temp_result_str;
                    done <= 1'b1;
                end
                
                ERROR: begin
                    error <= 1'b1;
                    result_str <= 64'd0;
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    result_str <= 64'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && data_valid) begin
                    if (valid_tuples > 5'd0) begin
                        next_state = LOAD;
                    end else begin
                        next_state = ERROR;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                // Scan all 16 tuples or until valid_tuples limit
                // Check completion condition
                if (scan_idx >= 4'd15 || scan_idx >= valid_tuples[3:0]) begin
                    next_state = UPDATE;
                end else if (timeout_counter >= TIMEOUT_MAX) begin
                    next_state = ERROR;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            UPDATE: begin
                next_state = DONE;
            end
            
            DONE: begin
                // Return to IDLE after one cycle of done
                next_state = IDLE;
            end
            
            ERROR: begin
                // Return to IDLE after error
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule