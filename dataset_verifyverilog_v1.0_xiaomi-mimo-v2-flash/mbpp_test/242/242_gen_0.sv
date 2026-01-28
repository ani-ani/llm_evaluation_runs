module char_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNTING  = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] index;          // Current character index (0-15)
    reg [3:0] target_len;     // Stores len value for processing
    reg [4:0] count_reg;      // Accumulated count (0-16)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            index <= 4'd0;
            target_len <= 4'd0;
            count_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    count_reg <= 5'd0;
                    
                    if (start) begin
                        target_len <= len;
                        if (len == 4'd0) begin
                            // Immediate completion for len=0
                            result <= 5'd0;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            state <= COUNTING;
                        end
                    end
                end
                
                COUNTING: begin
                    // Process current character
                    if (str[index] != 8'h00) begin
                        count_reg <= count_reg + 5'd1;
                    end
                    
                    // Move to next character
                    index <= index + 4'd1;
                    
                    // Check if we've processed all characters or reached len
                    if ((index + 4'd1) >= target_len) begin
                        result <= count_reg;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 5'd0;
                    done <= 1'b0;
                    index <= 4'd0;
                    target_len <= 4'd0;
                    count_reg <= 5'd0;
                end
            endcase
        end
    end

endmodule