module divisor_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] result,
    output reg done
);
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] counter;
    reg [7:0] divisor_count;
    reg [7:0] n_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            counter <= 8'd0;
            divisor_count <= 8'd0;
            n_reg <= 8'd0;
        end 
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        divisor_count <= 8'd0;
                        counter <= 8'd1;
                        state <= (n == 8'd0) ? FINISH : COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (n_reg % counter == 8'd0) begin
                        divisor_count <= divisor_count + 8'd1;
                    end
                    
                    if (counter < n_reg) begin
                        counter <= counter + 8'd1;
                    end
                    else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= divisor_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule