module fibfib_sequence(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] counter;
    reg [15:0] a, b, c;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 8'd0;
            a <= 16'd0;
            b <= 16'd0;
            c <= 16'd1;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        counter <= 8'd2;
                        a <= 16'd0;
                        b <= 16'd0;
                        c <= 16'd1;
                        if (n == 8'd0 || n == 8'd1) begin
                            result <= 16'd0;
                            state <= FINISH;
                        end else if (n == 8'd2) begin
                            result <= 16'd1;
                            state <= FINISH;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (counter == n) begin
                        result <= c;
                        state <= FINISH;
                    end else begin
                        a <= b;
                        b <= c;
                        c <= a + b + c;
                        counter <= counter + 8'd1;
                    end
                    
                    // Safety: prevent infinite loops
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