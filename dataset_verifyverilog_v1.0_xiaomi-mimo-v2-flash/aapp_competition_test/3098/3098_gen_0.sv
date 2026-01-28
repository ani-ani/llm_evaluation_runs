module expected_kgon_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [31:0] x [0:15],
    input wire [31:0] y [0:15],
    output reg [63:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_AREA = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] DONE      = 3'd3;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i_counter; // Loop counter for area calc (0 to n-1)
    reg [7:0] div_counter; // Counter for division cycles (0 to 63)
    reg [63:0] area_acc; // Accumulator for polygon area
    reg [63:0] prod_temp; // Temporary for multiplication
    reg [63:0] numerator; // For division: Total_Area * k
    reg [63:0] divisor;   // For division: n
    reg [63:0] quotient;
    reg [63:0] remainder;
    reg [3:0] k_reg; // Registered k
    reg [3:0] n_reg; // Registered n
    reg signed [31:0] x0, y0, x1, y1, x2, y2;
    reg signed [63:0] cross_prod;
    wire signed [63:0] area_triangle;

    // Cross product: (x[i]-x[0])*(y[i+1]-y[0]) - (y[i]-y[0])*(x[i+1]-x[0])
    // All inputs are Q16.16, result is Q32.32 (shifted left 16 bits)
    assign area_triangle = ((x1 - x0) * (y2 - y0)) - ((y1 - y0) * (x2 - x0));

    // Next State Logic
    always @(*) begin
        next_state = state; // Default hold
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC_AREA;
            end
            CALC_AREA: begin
                if (i_counter == n_reg[3:0]) // n <= 16, so compare to registered n
                    next_state = DIVIDE;
            end
            DIVIDE: begin
                if (div_counter == 8'd64) // 64-bit restoring division
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            i_counter <= 4'd0;
            div_counter <= 8'd0;
            area_acc <= 64'd0;
            numerator <= 64'd0;
            divisor <= 64'd0;
            quotient <= 64'd0;
            remainder <= 64'd0;
            k_reg <= 4'd0;
            n_reg <= 4'd0;
            x0 <= 32'd0; y0 <= 32'd0;
            x1 <= 32'd0; y1 <= 32'd0;
            x2 <= 32'd0; y2 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k_reg <= k;
                        n_reg <= n;
                        area_acc <= 64'd0;
                        i_counter <= 4'd0;
                        // Register vertex 0 coordinates for repeated use
                        x0 <= x[0];
                        y0 <= y[0];
                    end
                end

                CALC_AREA: begin
                    // Loop from 0 to n-1
                    // i=0 is degenerate (0,0,0), produces 0 area
                    // i=1 uses vertex 1 and vertex 2 (index wraps to 0)
                    // Last iteration uses vertex n-1 and vertex 0
                    
                    if (i_counter < n_reg) begin
                        // Fetch vertices for current triangle
                        // Triangle: (0, i, i+1) where index wraps for i+1
                        x1 <= x[i_counter];
                        y1 <= y[i_counter];
                        
                        // Handle wrap around for i+1
                        if (i_counter + 4'd1 == n_reg) begin
                            x2 <= x[0];
                            y2 <= y[0];
                        end else begin
                            x2 <= x[i_counter + 4'd1];
                            y2 <= y[i_counter + 4'd1];
                        end

                        // Accumulate
                        if (i_counter == 4'd0) begin
                            // First triangle is (0,0,0) -> area 0
                            area_acc <= area_acc;
                        end else begin
                            // area_triangle is Q32.32 already (since inputs are Q16.16)
                            // Sum is Q32.32
                            area_acc <= area_acc + area_triangle;
                        end
                        
                        i_counter <= i_counter + 4'd1;
                    end
                end

                DIVIDE: begin
                    if (div_counter == 8'd0) begin
                        // Initialization step for division
                        // Numerator = Area * k
                        // area_acc is Q32.32, k is integer. Result is Q32.32
                        prod_temp <= area_acc * k_reg;
                        
                        // Prepare for restoring division: Numerator / n
                        // We treat numerator as 64-bit unsigned integer for division
                        // Result will be Q32.32
                        numerator <= prod_temp; // Assign the previous cycle's product
                        divisor <= {60'd0, n_reg}; // n <= 16
                        quotient <= 64'd0;
                        remainder <= 64'd0;
                        div_counter <= 8'd1;
                    end else if (div_counter <= 8'd64) begin
                        // Restoring division algorithm (64 iterations for 64-bit result)
                        // Shift numerator left into remainder
                        remainder <= {remainder[62:0], numerator[63]};
                        numerator <= {numerator[62:0], 1'b0};
                        quotient <= {quotient[62:0], 1'b0};

                        if (remainder >= divisor) begin
                            remainder <= remainder - divisor;
                            quotient <= {quotient[62:0], 1'b1};
                        end
                        
                        div_counter <= div_counter + 8'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= quotient; // Q32.32 result
                end
            endcase
        end
    end
endmodule