module SequentialOverlapDetection(
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [2:0] len1,
    input [2:0] len2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [2:0] i_reg;
    reg [2:0] j_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        i_reg <= 3'd0;
                        j_reg <= 3'd0;
                        result <= 1'b0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current elements match
                    if (list1[i_reg] == list2[j_reg]) begin
                        result <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Move to next element
                        j_reg <= j_reg + 3'd1;
                        
                        // Check if reached end of list2
                        if (j_reg >= len2) begin
                            j_reg <= 3'd0;
                            i_reg <= i_reg + 3'd1;
                            
                            // Check if reached end of list1
                            if (i_reg >= len1) begin
                                state <= FINISH;
                            end
                        end
                    end
                    
                    // Safety check for max cycles
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