module DecagonalNumberCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] STAGE1  = 3'd1;
    localparam [2:0] STAGE2  = 3'd2;
    localparam [2:0] STAGE3  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] n_squared;
    reg [17:0] n4_temp;
    reg [15:0] n4;
    reg [9:0] n3;
    reg [15:0] result_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_squared <= 16'd0;
            n4_temp <= 18'd0;
            n4 <= 16'd0;
            n3 <= 10'd0;
            result_temp <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= STAGE1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                STAGE1: begin
                    cycle_count <= cycle_count + 8'd1;
                    n_squared <= n * n;
                    next_state <= STAGE2;
                end
                
                STAGE2: begin
                    cycle_count <= cycle_count + 8'd1;
                    n4_temp <= n_squared << 2;
                    n4 <= (n4_temp > 16'd65535) ? 16'd65535 : n4_temp[15:0];
                    next_state <= STAGE3;
                end
                
                STAGE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    n3 <= (n << 1) + n;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result_temp <= n4 - n3;
                    result <= result_temp;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule