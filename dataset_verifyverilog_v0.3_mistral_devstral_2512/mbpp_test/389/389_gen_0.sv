module lucas_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,  // n value (0-16)
    output reg [31:0] result,
    output reg done
);

    // FSM states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [4:0] current_n;
    reg [31:0] a, b;  // L(i-1) and L(i-2)
    reg [31:0] next_a, next_b;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            current_n <= 5'd0;
            a <= 32'd0;
            b <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            if (state == COMPUTE) begin
                a <= next_a;
                b <= next_b;
                current_n <= current_n - 5'd1;
                cycle_count <= cycle_count + 8'd1;
            end else if (state == FINISH) begin
                result <= a;
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
                cycle_count <= 8'd0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_a = a;
        next_b = b;
        
        case(state)
            IDLE: begin
                if (start) begin
                    if (n == 5'd0) begin
                        result = 32'd2;
                        next_state = FINISH;
                    end else if (n == 5'd1) begin
                        result = 32'd1;
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE;
                        next_a = 32'd1;  // L(1)
                        next_b = 32'd2;  // L(0)
                        current_n = n;
                    end
                end
            end
            
            COMPUTE: begin
                next_a = a + b;  // L(i) = L(i-1) + L(i-2)
                next_b = a;
                if (current_n <= 5'd2 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule