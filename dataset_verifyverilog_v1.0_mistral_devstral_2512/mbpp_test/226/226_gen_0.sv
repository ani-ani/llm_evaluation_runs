module odd_values_string (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],  // 16-character input string (ASCII bytes)
    input wire [4:0] len,          // Actual string length (0-16)
    output reg [7:0] result [0:7], // Result: max 8 chars (for 16-char input)
    output reg done,
    output reg [3:0] result_len    // Result length
);

    // State machine states
    reg [2:0] state;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal counters and registers
    reg [4:0] i;  // Input index
    reg [3:0] j;  // Output index
    reg [4:0] len_reg;  // Store length
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 8'd0;
            end
            i <= 5'd0;
            j <= 4'd0;
            len_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 5'd0;
                        j <= 4'd0;
                        len_reg <= len;
                        // Clear result array
                        for (k = 0; k < 8; k = k + 1) begin
                            result[k] <= 8'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (i < len_reg && j < 8) begin
                        // Check if index is even (i % 2 == 0)
                        if (i[0] == 1'b0) begin  // Even index
                            result[j] <= str[i];
                            j <= j + 1;
                        end
                        i <= i + 1;
                    end else begin
                        // Done processing
                        result_len <= j;
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