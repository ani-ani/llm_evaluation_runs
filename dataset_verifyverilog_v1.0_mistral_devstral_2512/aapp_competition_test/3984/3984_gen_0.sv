module game_solver (
    input clk,
    input rst_n,
    input start,
    input [127:0] packed_s,
    input [4:0] len,
    output reg [15:0] winner,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [4:0] k;
    reg [7:0] min_char;
    reg [15:0] result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k <= 5'd0;
            min_char <= 8'd255;
            winner <= 16'd0;
            done <= 1'b0;
            result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        k <= 5'd0;
                        min_char <= 8'd255;
                        result <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (k < len) begin
                        reg [7:0] current_char;
                        current_char = packed_s[k*8 +: 8];
                        
                        result[k] <= (min_char < current_char);
                        min_char <= (min_char < current_char) ? min_char : current_char;
                        k <= k + 5'd1;
                    end else begin
                        winner <= result;
                        state <= FINISH;
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