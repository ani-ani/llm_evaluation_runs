module warlord_sectors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] W,
    input wire [6:0] N,
    input wire signed [11:0] x1,
    input wire signed [11:0] y1,
    input wire signed [11:0] x2,
    input wire signed [11:0] y2,
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (N == 7'd0) begin
                        result <= (W + 4'd1) >> 1;
                    end else begin
                        if (W > 2*N) begin
                            result <= W - 2*N;
                        end else begin
                            result <= 8'd0;
                        end
                    end
                    
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