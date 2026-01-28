module first_repeated_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_CHAR = 3'd1;
    localparam [2:0] COMPARE    = 3'd2;
    localparam [2:0] RESULT     = 3'd3;
    
    reg [2:0] state;
    reg [3:0] i;           // Outer loop index
    reg [3:0] j;           // Inner loop index
    reg [7:0] current_char; // Current character being checked
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            current_char <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_CHAR;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                CHECK_CHAR: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        current_char <= str[i];
                        j <= 4'd0;
                        state <= COMPARE;
                    end else begin
                        // No repeats found
                        result <= 8'd0;
                        state <= RESULT;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (j < i) begin
                        if (str[j] == current_char) begin
                            // Found a repeat
                            result <= current_char;
                            state <= RESULT;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else begin
                        // No match for this character, move to next
                        i <= i + 4'd1;
                        state <= CHECK_CHAR;
                    end
                end
                
                RESULT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule