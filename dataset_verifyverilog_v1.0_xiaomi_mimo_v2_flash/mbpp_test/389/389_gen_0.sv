module lucas_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // FSM states
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] ITERATE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    reg [4:0] current_n;
    reg [31:0] a, b;
    reg [31:0] next_a, next_b;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            current_n <= 5'd0;
            a <= 32'd0;
            b <= 32'd0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case(state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        current_n <= n;
                        if (n == 5'd0) begin
                            result <= 32'd2;
                        end else if (n == 5'd1) begin
                            result <= 32'd1;
                        end else begin
                            a <= 32'd1;
                            b <= 32'd2;
                        end
                    end
                end
                
                COMPUTE: begin
                    next_a <= a + b;
                    next_b <= a;
                    current_n <= current_n - 5'd1;
                    cycle_count <= cycle_count + 5'd1;
                    if (current_n <= 5'd2) begin
                        result <= a + b;
                    end
                end
                
                ITERATE: begin
                    next_a <= a + b;
                    next_b <= a;
                    current_n <= current_n - 5'd1;
                    cycle_count <= cycle_count + 5'd1;
                    if (current_n <= 5'd1) begin
                        result <= a + b;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
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
                    if (n <= 5'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE;
                    end
                end
            end
            
            COMPUTE: begin
                if (current_n <= 5'd2 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = ITERATE;
                end
                next_a = a + b;
                next_b = a;
            end
            
            ITERATE: begin
                next_a = a + b;
                next_b = a;
                if (current_n <= 5'd1 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = ITERATE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule