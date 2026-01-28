module StringPatternChecker(
    input clk,
    input rst_n,
    input start,
    input [7:0] string_chars [0:15],
    input valid_chars [0:15],
    output reg match,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK = 4'd1;
    localparam [3:0] FINISH = 4'd2;
    
    reg [3:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;
    
    reg first_char_a;
    reg last_char_b;
    reg [3:0] last_valid_index;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            first_char_a <= 1'b0;
            last_char_b <= 1'b0;
            last_valid_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Find last valid character index
                    last_valid_index <= 4'd0;
                    for (i = 15; i >= 0; i = i - 1) begin
                        if (valid_chars[i]) begin
                            last_valid_index <= i;
                            break;
                        end
                    end
                    
                    // Check first character is 'a' (0x61) and last valid character is 'b' (0x62)
                    first_char_a <= (valid_chars[0] && (string_chars[0] == 8'd97));
                    last_char_b <= (valid_chars[last_valid_index] && (string_chars[last_valid_index] == 8'd98));
                    
                    // Determine match condition
                    if (first_char_a && last_char_b) begin
                        match <= 1'b1;
                    end else begin
                        match <= 1'b0;
                    end
                    
                    // Transition to finish
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule