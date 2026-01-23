module find_rectangle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [31:0] m,
    input wire [31:0] x,
    input wire [31:0] y,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] x1,
    output reg [31:0] y1,
    output reg [31:0] x2,
    output reg [31:0] y2,
    output reg done
);

    // State definitions
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_GCD = 4'd1;
    localparam [3:0] S_REDUCE = 4'd2;
    localparam [3:0] S_SCALE = 4'd3;
    localparam [3:0] S_POSITION = 4'd4;
    localparam [3:0] S_DONE = 4'd5;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers for intermediate results
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg [31:0] gcd_temp;
    reg [31:0] a_reduced;
    reg [31:0] b_reduced;
    reg [31:0] k;
    reg [31:0] width;
    reg [31:0] height;
    reg [31:0] cx;
    reg [31:0] cy;
    reg [31:0] dx;
    reg [31:0] dy;
    reg [31:0] max_k;
    reg [31:0] div_temp;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start) next_state = S_GCD;
                else next_state = S_IDLE;
            end
            S_GCD: begin
                if (gcd_b == 0) next_state = S_REDUCE;
                else next_state = S_GCD;
            end
            S_REDUCE: next_state = S_SCALE;
            S_SCALE: next_state = S_POSITION;
            S_POSITION: next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end
    
    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x1 <= 0; y1 <= 0; x2 <= 0; y2 <= 0; done <= 0;
            gcd_a <= 0; gcd_b <= 0; gcd_temp <= 0;
            a_reduced <= 0; b_reduced <= 0;
            k <= 0; width <= 0; height <= 0;
            cx <= 0; cy <= 0; dx <= 0; dy <= 0;
            max_k <= 0; div_temp <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        gcd_a <= a;
                        gcd_b <= b;
                    end
                end
                
                S_GCD: begin
                    if (gcd_b != 0) begin
                        gcd_temp <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_temp;
                    end
                end
                
                S_REDUCE: begin
                    a_reduced <= a / gcd_a;
                    b_reduced <= b / gcd_a;
                end
                
                S_SCALE: begin
                    // Compute min(n / a_reduced, m / b_reduced)
                    if (a_reduced != 0 && b_reduced != 0) begin
                        if (n / a_reduced < m / b_reduced) begin
                            k <= n / a_reduced;
                        end else begin
                            k <= m / b_reduced;
                        end
                    end else begin
                        k <= 0;
                    end
                    // Compute width and height
                    width <= a_reduced * k;
                    height <= b_reduced * k;
                end
                
                S_POSITION: begin
                    // Compute center offsets
                    cx <= (width + 1) >> 1;  // (width + 1) // 2
                    cy <= (height + 1) >> 1; // (height + 1) // 2
                    
                    // Compute dx and dy
                    if (x > cx) begin
                        dx <= x - cx;
                    end else begin
                        dx <= 0;
                    end
                    
                    if (y > cy) begin
                        dy <= y - cy;
                    end else begin
                        dy <= 0;
                    end
                    
                    // Clamp to boundaries
                    if (dx + width > n) begin
                        dx <= n - width;
                    end
                    
                    if (dy + height > m) begin
                        dy <= m - height;
                    end
                    
                    // Compute final outputs
                    x1 <= dx;
                    y1 <= dy;
                    x2 <= dx + width;
                    y2 <= dy + height;
                end
                
                S_DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule