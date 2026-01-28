module MaxMinDiff(
    input wire clk,
    input wire rst_n,
    input wire start,
    input [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;
    reg [7:0] min_reg;
    reg [7:0] max_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            min_reg <= 8'd0;
            max_reg <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        counter <= 3'd0;
                        min_reg <= arr[0];
                        max_reg <= arr[0];
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update min and max
                    if (arr[counter] < min_reg) begin
                        min_reg <= arr[counter];
                    end
                    if (arr[counter] > max_reg) begin
                        max_reg <= arr[counter];
                    end
                    
                    // Increment counter
                    counter <= counter + 3'd1;
                    
                    // Check if done or timeout
                    if ((counter == 3'd7) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= {8'd0, max_reg} - {8'd0, min_reg};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule