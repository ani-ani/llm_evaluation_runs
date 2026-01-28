module count_substr(
    input clk,
    input rst_n,
    input start,
    input [63:0] s,
    input [2:0] length,
    output reg [15:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [2:0] cycle_count;
    reg [3:0] current_sum;
    reg [3:0] current_diff;
    reg [7:0] char_index;
    reg [7:0] diff_count [0:80]; // 0-80 range for (sum - index) + 8
    reg [15:0] result;
    reg [2:0] char_pos;
    
    // Initialize diff_count array
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 3'd0;
            current_sum <= 4'd0;
            current_diff <= 4'd0;
            char_index <= 8'd0;
            result <= 16'd0;
            char_pos <= 3'd0;
            done <= 1'b0;
            count <= 16'd0;
            for (i = 0; i < 81; i = i + 1) begin
                diff_count[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    current_sum <= 4'd0;
                    current_diff <= 4'd0;
                    char_index <= 8'd0;
                    result <= 16'd0;
                    char_pos <= 3'd0;
                    if (start) begin
                        state <= PROCESS;
                        // Initialize diff_count[8] for diff=0 (sum-index=-8)
                        diff_count[8] <= 8'd1; // Base case: empty prefix
                    end
                end
                
                PROCESS: begin
                    // Extract current character
                    reg [7:0] current_char;
                    case (char_pos)
                        3'd0: current_char = s[63:56];
                        3'd1: current_char = s[55:48];
                        3'd2: current_char = s[47:40];
                        3'd3: current_char = s[39:32];
                        3'd4: current_char = s[31:24];
                        3'd5: current_char = s[23:16];
                        3'd6: current_char = s[15:8];
                        3'd7: current_char = s[7:0];
                        default: current_char = 8'd48; // '0'
                    endcase
                    
                    // Convert ASCII to digit
                    reg [3:0] digit;
                    digit = current_char - 8'd48;
                    
                    // Update current_sum and current_diff
                    current_sum <= current_sum + digit;
                    current_diff <= current_sum - char_index;
                    
                    // Calculate index for diff_count (offset by 8)
                    reg [6:0] diff_index;
                    diff_index = current_diff + 8;
                    
                    // Update result with count of previous occurrences
                    result <= result + diff_count[diff_index];
                    
                    // Increment count for this diff
                    diff_count[diff_index] <= diff_count[diff_index] + 8'd1;
                    
                    // Move to next character
                    char_index <= char_index + 8'd1;
                    char_pos <= char_pos + 3'd1;
                    
                    // Check if processing is complete
                    if (char_pos == length) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    count <= result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule