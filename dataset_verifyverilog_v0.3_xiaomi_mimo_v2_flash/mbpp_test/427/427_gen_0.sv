module DateConverter (
    input clk,
    input rst_n,
    input start,
    input [7:0] date_in [0:9],
    output reg [7:0] date_out [0:9],
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CONVERT = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] date_reg [0:9];
    reg [3:0] i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < 10; i = i + 1) begin
                date_out[i] <= 8'd0;
                date_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CONVERT;
                        // Store input for processing
                        for (i = 0; i < 10; i = i + 1) begin
                            date_reg[i] <= date_in[i];
                        end
                    end
                end
                
                CONVERT: begin
                    // Rearrange: dd-mm-yyyy
                    // Input: yyyy-mm-dd (positions 0-3, 5-6, 8-9)
                    // Output: dd-mm-yyyy (positions 0-1, 3-4, 6-9)
                    
                    // Day (positions 0-1 in output from positions 8-9 in input)
                    date_out[0] <= date_reg[8];  // First digit of day
                    date_out[1] <= date_reg[9];  // Second digit of day
                    
                    // Separator at position 2
                    date_out[2] <= 8'd45;  // ASCII '-'
                    
                    // Month (positions 3-4 in output from positions 5-6 in input)
                    date_out[3] <= date_reg[5];  // First digit of month
                    date_out[4] <= date_reg[6];  // Second digit of month
                    
                    // Separator at position 5
                    date_out[5] <= 8'd45;  // ASCII '-'
                    
                    // Year (positions 6-9 in output from positions 0-3 in input)
                    date_out[6] <= date_reg[0];  // First digit of year
                    date_out[7] <= date_reg[1];  // Second digit of year
                    date_out[8] <= date_reg[2];  // Third digit of year
                    date_out[9] <= date_reg[3];  // Fourth digit of year
                    
                    state <= FINISH;
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