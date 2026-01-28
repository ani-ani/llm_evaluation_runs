module remove_char(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [7:0] str_in [0:15],
    output reg [7:0] result [0:15],
    output reg [3:0] length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] FIND_FIRST  = 3'd1;
    localparam [2:0] SHIFT_FIRST = 3'd2;
    localparam [2:0] FIND_LAST   = 3'd3;
    localparam [2:0] SHIFT_LAST  = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] working_str [0:15];
    reg [3:0] idx;
    reg [3:0] first_pos;
    reg [3:0] last_pos;
    reg [3:0] cycle_count;
    reg first_found;
    reg last_found;
    reg [3:0] temp_length;
    
    // Initialize all arrays
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            length <= 4'd0;
            cycle_count <= 4'd0;
            idx <= 4'd0;
            first_pos <= 4'd0;
            last_pos <= 4'd0;
            first_found <= 1'b0;
            last_found <= 1'b0;
            temp_length <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                working_str[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    idx <= 4'd0;
                    first_found <= 1'b0;
                    last_found <= 1'b0;
                    
                    if (start) begin
                        // Load input into working buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            working_str[i] <= str_in[i];
                        end
                        temp_length <= 4'd15; // Fixed width
                        state <= FIND_FIRST;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                FIND_FIRST: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Scan for first occurrence
                    if (!first_found && idx < 16 && working_str[idx] == char_in) begin
                        first_pos <= idx;
                        first_found <= 1'b1;
                        // Continue scanning to find actual first (lowest index)
                    end
                    
                    if (idx >= 16) begin
                        if (first_found) begin
                            state <= SHIFT_FIRST;
                        end else begin
                            // Character not found, skip to done
                            state <= FINISH;
                        end
                    end else begin
                        idx <= idx + 4'd1;
                        state <= FIND_FIRST;
                    end
                end
                
                SHIFT_FIRST: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Shift array left to remove first occurrence
                    for (i = 0; i < 15; i = i + 1) begin
                        if (i < first_pos) begin
                            working_str[i] <= working_str[i];
                        end else begin
                            working_str[i] <= working_str[i + 1];
                        end
                    end
                    working_str[15] <= 8'd0;
                    
                    temp_length <= temp_length - 4'd1;
                    idx <= 4'd0; // Reset index for find last
                    state <= FIND_LAST;
                end
                
                FIND_LAST: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Find last occurrence in modified string
                    if (idx < temp_length && working_str[idx] == char_in) begin
                        last_pos <= idx;
                        last_found <= 1'b1;
                    end
                    
                    if (idx >= temp_length) begin
                        if (last_found) begin
                            state <= SHIFT_LAST;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        idx <= idx + 4'd1;
                        state <= FIND_LAST;
                    end
                end
                
                SHIFT_LAST: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Shift array left to remove last occurrence
                    for (i = 0; i < 15; i = i + 1) begin
                        if (i < last_pos) begin
                            working_str[i] <= working_str[i];
                        end else begin
                            working_str[i] <= working_str[i + 1];
                        end
                    end
                    working_str[15] <= 8'd0;
                    
                    temp_length <= temp_length - 4'd1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    // Copy to output and set done
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= working_str[i];
                    end
                    length <= temp_length;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety: return to idle if cycle limit exceeded
            if (cycle_count >= 100 && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end

endmodule