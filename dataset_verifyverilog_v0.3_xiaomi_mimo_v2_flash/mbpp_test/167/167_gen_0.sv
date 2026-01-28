module next_power_of_2 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [8:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] temp_n;
    reg [7:0] original_n;
    reg [3:0] count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 9'd0;
            done <= 1'b0;
            temp_n <= 8'd0;
            original_n <= 8'd0;
            count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 8'd0) begin
                            result <= 9'd1;
                            done <= 1'b1;
                            state <= FINISH;
                        end else begin
                            original_n <= n;
                            temp_n <= n;
                            count <= 4'd0;
                            state <= CALC;
                        end
                    end
                end
                
                CALC: begin
                    if (temp_n != 8'd0) begin
                        temp_n <= {1'b0, temp_n[7:1]};
                        count <= count + 1'b1;
                    end else begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check if original_n is already a power of 2
                    // (original_n & (original_n - 1)) == 0 for powers of 2
                    if (count > 4'd1 && (original_n & (original_n - 1'b1)) == 8'd0) begin
                        result <= {1'b0, original_n};
                    end else begin
                        result <= 9'd1 << count;
                    end
                    done <= 1'b1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule