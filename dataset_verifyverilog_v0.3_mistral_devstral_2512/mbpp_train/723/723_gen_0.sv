module count_same_pair (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr1 [0:7],
    input wire signed [7:0] arr2 [0:7],
    output reg signed [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [2:0] idx;
    reg [3:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'd0;
            count <= 4'd0;
            result <= 16'sd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        idx <= 3'd0;
                        count <= 4'd0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (arr1[idx] == arr2[idx]) begin
                        count <= count + 4'd1;
                    end
                    
                    if (idx == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end
                
                FINISH: begin
                    result <= {{12{1'b0}}, count};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule