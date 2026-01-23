module caesar_decode (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output reg [7:0] char_out,
    output reg char_out_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 1'b0;
    localparam PROCESSING = 1'b1;
    
    reg state;
    reg [7:0] char_shifted;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'b0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Default assignments
            char_out_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    if (char_valid) begin
                        // Check if lowercase letter (0x61-0x7A)
                        if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                            // Shift backward by 5 (add 21 modulo 26)
                            char_shifted <= 8'h61 + ((char_in - 8'h61 + 21) % 8'd26);
                        end else begin
                            // Pass through unchanged
                            char_shifted <= char_in;
                        end
                        char_out_valid <= 1'b1;
                    end
                    
                    if (char_done) begin
                        state <= IDLE;
                        done <= 1'b1;
                    end
                    
                    // Output the registered shifted character
                    char_out <= char_shifted;
                end
            endcase
        end
    end

endmodule