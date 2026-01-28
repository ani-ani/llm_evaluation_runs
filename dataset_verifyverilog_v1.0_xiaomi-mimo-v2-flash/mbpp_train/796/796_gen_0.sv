module DictionarySum(
    input clk,
    input rst_n,
    input start,
    input [7:0] keys [0:7],
    input [15:0] values [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SUM  = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;
    reg [15:0] accumulator;
    
    // Synthesis directives for FPGA implementation
    (* syn_keep *) reg [15:0] result_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            result_reg <= 16'd0;
            done <= 1'b0;
            index <= 3'd0;
            accumulator <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    accumulator <= 16'd0;
                    if (start) begin
                        if (len == 4'd0) begin
                            // No entries to process
                            result_reg <= 16'd0;
                            state <= DONE;
                        end else begin
                            state <= SUM;
                        end
                    end
                end
                
                SUM: begin
                    // Process current entry if within valid range
                    if (index < len) begin
                        // Check if key is not all zeros (valid entry)
                        if (keys[index] != 8'd0) begin
                            accumulator <= accumulator + values[index];
                        end
                        index <= index + 3'd1;
                    end else begin
                        // All entries processed
                        result_reg <= accumulator;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    result_reg <= 16'd0;
                    done <= 1'b0;
                    index <= 3'd0;
                    accumulator <= 16'd0;
                end
            endcase
        end
    end

endmodule