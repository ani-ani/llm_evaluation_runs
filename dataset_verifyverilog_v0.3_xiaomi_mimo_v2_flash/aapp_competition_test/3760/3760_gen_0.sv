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
    localparam [3:0] S_IDLE    = 4'd0;
    localparam [3:0] S_GCD     = 4'd1;
    localparam [3:0] S_REDUCE  = 4'd2;
    localparam [3:0] S_SCALE   = 4'd3;
    localparam [3:0] S_POSITION = 4'd4;
    localparam [3:0] S_DONE    = 4'd5;

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
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
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
                if (gcd_b == 32'd0) next_state = S_REDUCE;
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
            x1 <= 32'd0;
            y1 <= 32'd0;
            x2 <= 32'd0;
            y2 <= 32'd0;
            done <= 1'b0;
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            gcd_temp <= 32'd0;
            a_reduced <= 32'd0;
            b_reduced <= 32'd0;
            k <= 32'd0;
            width <= 32'd0;
            height <= 32'd0;
            cx <= 32'd0;
            cy <= 32'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            max_k <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        gcd_a <= a;
                        gcd_b <= b;
                    end
                end
                
                S_GCD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (gcd_b != 32'd0 && cycle_count < MAX_CYCLES) begin
                        gcd_temp <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_temp;
                    end
                end
                
                S_REDUCE: begin
                    if (gcd_a != 32'd0) begin
                        a_reduced <= a / gcd_a;
                        b_reduced <= b / gcd_a;
                    end else begin
                        a_reduced <= a;
                        b_reduced <= b;
                    end
                end
                
                S_SCALE: begin
                    // Compute min(n / a_reduced, m / b_reduced)
                    if (a_reduced != 32'd0 && b_reduced != 32'd0) begin
                        if (n / a_reduced < m / b_reduced) begin
                            k <= n / a_reduced;
                        end else begin
                            k <= m / b_reduced;
                        end
                    end else begin
                        k <= 32'd0;
                    end
                    // Compute width and height
                    width <= a_reduced * k;
                    height <= b_reduced * k;
                end
                
                S_POSITION: begin
                    // Compute center offsets
                    cx <= (width + 32'd1) >> 1;  // (width + 1) // 2
                    cy <= (height + 32'd1) >> 1; // (height + 1) // 2
                    
                    // Compute dx
                    if (x > cx) begin
                        dx <= x - cx;
                    end else begin
                        dx <= 32'd0;
                    end
                    
                    // Compute dy
                    if (y > cy) begin
                        dy <= y - cy;
                    end else begin
                        dy <= 32'd0;
                    end
                end
                
                S_DONE: begin
                    // Clamp to boundaries after position calculation
                    if (dx + width > n) begin
                        x1 <= n - width;
                    end else begin
                        x1 <= dx;
                    end
                    
                    if (dy + height > m) begin
                        y1 <= m - height;
                    end else begin
                        y1 <= dy;
                    end
                    
                    // Compute x2 and y2
                    x2 <= x1 + width;
                    y2 <= y1 + height;
                    done <= 1'b1;
                end
                
                default: begin
                    x1 <= 32'd0;
                    y1 <= 32'd0;
                    x2 <= 32'd0;
                    y2 <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule