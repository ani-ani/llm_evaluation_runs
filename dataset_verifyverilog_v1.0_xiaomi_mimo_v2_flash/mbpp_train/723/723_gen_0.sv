module count_same_pair (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr1 [0:7],
    input wire signed [7:0] arr2 [0:7],
    output reg signed [15:0] result,
    output reg done
);
    reg [2:0] idx;
    reg [3:0] count;
    reg [1:0] state;
    
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPARE = 2'b01;
    localparam [1:0] DONE = 2'b10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'b0;
            count <= 4'b0;
            result <= 16'sd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPARE;
                        idx <= 3'b0;
                        count <= 4'b0;
                    end
                end
                COMPARE: begin
                    if (arr1[idx] == arr2[idx]) begin
                        count <= count + 1'b1;
                    end
                    if (idx == 3'd7) begin
                        state <= DONE;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end
                DONE: begin
                    result <= {12'b0, count};
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule