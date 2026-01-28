module phone_counter (
    input clk,
    input rst_n,
    input start,
    input [99:0] digits_in,
    input [6:0] n,
    output reg [3:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNT_8   = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH    = 2'd3;
    
    reg [1:0] state, next_state;
    reg [6:0] idx;              // Index for counting (0-99)
    reg [3:0] count_8;          // Count of '8' digits (0-100, but max 100)
    reg [3:0] n_div_11;         // n//11 (0-9)
    reg [6:0] n_reg;            // Registered n
    reg count_done;             // Flag for counting completion
    
    // For n//11 calculation
    reg [6:0] n_remaining;
    reg [3:0] div_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 7'd0;
            count_8 <= 4'd0;
            n_div_11 <= 4'd0;
            n_reg <= 7'd0;
            count_done <= 1'b0;
            n_remaining <= 7'd0;
            div_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT_8;
                        idx <= 7'd0;
                        count_8 <= 4'd0;
                        n_reg <= n;
                        count_done <= 1'b0;
                    end
                end
                
                COUNT_8: begin
                    // Check if current character (in first n positions) is '8'
                    // digits_in is organized as bytes: bits[7:0] = char0, bits[15:8] = char1, etc.
                    // We need to check the 8-bit byte at position idx
                    if (idx < n_reg) begin
                        // Extract 8-bit byte from digits_in at position idx
                        if (digits_in[8*idx +: 8] == 8'h38) begin  // ASCII '8' = 0x38
                            count_8 <= count_8 + 4'd1;
                        end
                        idx <= idx + 7'd1;
                    end else begin
                        count_done <= 1'b1;
                        state <= CALCULATE;
                        n_remaining <= n_reg;
                        div_counter <= 4'd0;
                    end
                end
                
                CALCULATE: begin
                    // Calculate n//11 by repeated subtraction
                    if (n_remaining >= 7'd11) begin
                        n_remaining <= n_remaining - 7'd11;
                        div_counter <= div_counter + 4'd1;
                    end else begin
                        n_div_11 <= div_counter;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // result = min(count_8, n_div_11)
                    if (count_8 < n_div_11) begin
                        result <= count_8;
                    end else begin
                        result <= n_div_11;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule